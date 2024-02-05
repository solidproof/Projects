use std::ops::DerefMut;

use anchor_lang::{
    prelude::*,
    solana_program::{
        keccak,
        log::{sol_log, sol_log_64},
    },
};
use anchor_spl::token::{self, Token, TokenAccount, Transfer};
use rust_decimal::{
    prelude::{FromPrimitive, ToPrimitive},
    Decimal,
};

declare_id!("6cJU4mUJe1fKXzvvbZjz72M3d5aQXMmRV2jeQerkFw5b");

#[error_code]
pub enum ErrorCode {
    MaxAdmins,
    AdminNotFound,
    InvalidAmountTransferred,
    InvalidProof,
    AlreadyClaimed,
    NotOwner,
    NotAdminOrOwner,
    ChangingPauseValueToTheSame,
    Paused,
    EmptySchedule,
    InvalidScheduleOrder,
    PercentageDoesntCoverAllTokens,
    EmptyPeriod,
    IntegerOverflow,
    VestingAlreadyStarted,
    NothingToClaim,
    InvalidIntervalDuration,
}

/// This event is triggered whenever a call to claim succeeds.
#[event]
pub struct Claimed {
    merkle_index: u64,
    account: Pubkey,
    token_account: Pubkey,
    amount: u64,
}

/// This event is triggered whenever the merkle root gets updated.
#[event]
pub struct MerkleRootUpdated {
    merkle_index: u64,
    merkle_root: [u8; 32],
}

/// This event is triggered whenever a call to withdraw by owner succeeds.
#[event]
pub struct TokensWithdrawn {
    token: Pubkey,
    amount: u64,
}

#[program]
pub mod claiming_factory {
    use super::*;

    pub fn initialize_config(ctx: Context<InitializeConfig>, bump: u8) -> Result<()> {
        let config = ctx.accounts.config.deref_mut();

        *config = Config {
            owner: ctx.accounts.owner.key(),
            admins: [None; 10],
            bump,
        };

        Ok(())
    }

    pub fn initialize(ctx: Context<Initialize>, args: InitializeArgs) -> Result<()> {
        let distributor = ctx.accounts.distributor.deref_mut();

        *distributor = MerkleDistributor {
            merkle_index: 0,
            merkle_root: args.merkle_root,
            paused: false,
            vault_bump: args.vault_bump,
            vault: ctx.accounts.vault.key(),
            // schedule should pass validation first
            vesting: Vesting::new(args.schedule)?,
        };

        Ok(())
    }

    pub fn init_user_details(ctx: Context<InitUserDetails>, bump: u8) -> Result<()> {
        let user_details = ctx.accounts.user_details.deref_mut();

        *user_details = UserDetails {
            last_claimed_at_ts: 0,
            claimed_amount: 0,
            bump,
        };

        Ok(())
    }

    pub fn update_schedule(ctx: Context<UpdateSchedule>, args: UpdateScheduleArgs) -> Result<()> {
        let distributor = &mut ctx.accounts.distributor;

        require!(
            !distributor.vesting.has_started(&ctx.accounts.clock),
            VestingAlreadyStarted
        );

        for change in args.changes {
            distributor.vesting.apply_change(change);
        }

        distributor.vesting.validate()?;

        Ok(())
    }

    pub fn update_root(ctx: Context<UpdateRoot>, args: UpdateRootArgs) -> Result<()> {
        let distributor = &mut ctx.accounts.distributor;

        distributor.merkle_root = args.merkle_root;
        distributor.merkle_index += 1;

        emit!(MerkleRootUpdated {
            merkle_index: distributor.merkle_index,
            merkle_root: distributor.merkle_root
        });

        if args.unpause {
            distributor.paused = false;
        }

        Ok(())
    }

    pub fn set_paused(ctx: Context<SetPaused>, paused: bool) -> Result<()> {
        let distributor = &mut ctx.accounts.distributor;

        require!(distributor.paused != paused, ChangingPauseValueToTheSame);

        distributor.paused = paused;

        Ok(())
    }

    pub fn add_admin(ctx: Context<AddAdmin>) -> Result<()> {
        let config = &mut ctx.accounts.config;
        let admin = &ctx.accounts.admin;

        for admin_slot in config.admins.iter_mut() {
            match admin_slot {
                // this admin have been already added
                Some(admin_key) if *admin_key == admin.key() => {
                    return Ok(());
                }
                _ => {}
            }
        }

        for admin_slot in config.admins.iter_mut() {
            if let None = admin_slot {
                *admin_slot = Some(admin.key());
                return Ok(());
            }
        }
        // fails if available admin slot is not found
        Err(ErrorCode::MaxAdmins.into())
    }

    pub fn remove_admin(ctx: Context<RemoveAdmin>) -> Result<()> {
        let config = &mut ctx.accounts.config;
        let admin = &ctx.accounts.admin;

        for admin_slot in config.admins.iter_mut() {
            if let Some(admin_key) = admin_slot {
                if *admin_key == admin.key() {
                    *admin_slot = None;
                    return Ok(());
                }
            }
        }

        // fails if admin is not found
        Err(ErrorCode::AdminNotFound.into())
    }

    pub fn withdraw_tokens(ctx: Context<WithdrawTokens>, amount: u64) -> Result<()> {
        let vault = &mut ctx.accounts.vault;
        let distributor = &ctx.accounts.distributor;

        let distributor_key = distributor.key();
        let seeds = &[distributor_key.as_ref(), &[distributor.vault_bump]];
        let signers = &[&seeds[..]];

        TokenTransfer {
            amount,
            from: vault,
            to: &ctx.accounts.target_wallet,
            authority: &ctx.accounts.vault_authority,
            token_program: &ctx.accounts.token_program,
            signers: Some(signers),
        }
        .make()?;

        emit!(TokensWithdrawn {
            token: vault.mint,
            amount
        });

        Ok(())
    }

    pub fn claim(ctx: Context<Claim>, args: ClaimArgs) -> Result<()> {
        let vault = &mut ctx.accounts.vault;
        let distributor = &ctx.accounts.distributor;
        let user_details = &mut ctx.accounts.user_details;

        require!(!distributor.paused, Paused);
        require!(user_details.claimed_amount < args.amount, AlreadyClaimed);

        let leaf = [
            &ctx.accounts.user.key().to_bytes()[..],
            &args.amount.to_be_bytes(),
        ];
        let leaf = keccak::hashv(&leaf).0;

        let mut computed_hash = leaf;
        for proof_element in args.merkle_proof {
            if computed_hash <= proof_element {
                computed_hash = keccak::hashv(&[computed_hash.as_ref(), proof_element.as_ref()]).0;
            } else {
                computed_hash = keccak::hashv(&[proof_element.as_ref(), computed_hash.as_ref()]).0;
            }
        }

        require!(computed_hash == distributor.merkle_root, InvalidProof);

        let (bps_to_claim, bps_to_add) = distributor
            .vesting
            .bps_available_to_claim(ctx.accounts.clock.unix_timestamp as u64, &user_details);
        let amount = (Decimal::from_u64(args.amount).unwrap() * bps_to_claim)
            .ceil()
            .to_u64()
            .unwrap();
        // this amount is from airdropped periods
        let amount_to_add = (Decimal::from_u64(args.amount).unwrap() * bps_to_add)
            .ceil()
            .to_u64()
            .unwrap();
        require!(amount > 0, NothingToClaim);

        let distributor_key = distributor.key();
        let seeds = &[distributor_key.as_ref(), &[distributor.vault_bump]];
        let signers = &[&seeds[..]];

        TokenTransfer {
            amount,
            from: vault,
            to: &ctx.accounts.target_wallet,
            authority: &ctx.accounts.vault_authority,
            token_program: &ctx.accounts.token_program,
            signers: Some(signers),
        }
        .make()?;

        user_details.claimed_amount += amount;
        user_details.claimed_amount += amount_to_add;

        user_details.last_claimed_at_ts = ctx.accounts.clock.unix_timestamp as u64;

        emit!(Claimed {
            merkle_index: distributor.merkle_index,
            account: ctx.accounts.user.key(),
            token_account: ctx.accounts.target_wallet.key(),
            amount,
        });

        Ok(())
    }
}

#[account]
#[derive(Debug)]
pub struct Config {
    owner: Pubkey,
    admins: [Option<Pubkey>; 10],
    bump: u8,
}

impl Config {
    pub const LEN: usize = std::mem::size_of::<Self>() + 8;
}

#[account]
pub struct UserDetails {
    last_claimed_at_ts: u64,
    claimed_amount: u64,
    bump: u8,
}

impl UserDetails {
    pub const LEN: usize = 8 + std::mem::size_of::<Self>();
}

const DECIMALS: u32 = 9;

#[derive(AnchorSerialize, AnchorDeserialize, Debug, Clone)]
pub struct Period {
    /// Percentage in kinda Basis Points (BPS). 1% = 1_000_000_000 BPS.
    /// NOTE: Percentage is for the whole period.
    pub token_percentage: u64,
    pub start_ts: u64,
    pub interval_sec: u64,
    pub times: u64,
    /// We should skip this in claim amount calculation
    /// because it has been claimed outside of this vesting scope.
    pub airdropped: bool,
}

#[derive(AnchorSerialize, AnchorDeserialize, Debug, Clone)]
pub struct Vesting {
    schedule: Vec<Period>,
}

impl Vesting {
    fn new(schedule: Vec<Period>) -> Result<Self> {
        let s = Self { schedule };

        s.validate()?;

        Ok(s)
    }

    fn validate(&self) -> Result<()> {
        require!(self.schedule.len() > 0, EmptySchedule);

        let mut last_start_ts = 0;
        let mut total_percentage = 0;

        for entry in &self.schedule {
            require!(entry.times > 0, EmptyPeriod);
            require!(entry.interval_sec > 0, InvalidIntervalDuration);
            require!(last_start_ts < entry.start_ts, InvalidScheduleOrder);

            // start_ts + (times * interval_sec)
            last_start_ts = entry
                .times
                .checked_mul(entry.interval_sec)
                .ok_or(ErrorCode::IntegerOverflow)?
                .checked_add(entry.start_ts)
                .ok_or(ErrorCode::IntegerOverflow)?;

            total_percentage += entry.token_percentage;
        }

        // 100% == 100_000_000_000 basis points
        require!(
            total_percentage == 100 * 10u64.pow(DECIMALS),
            PercentageDoesntCoverAllTokens
        );

        Ok(())
    }

    fn has_started(&self, clock: &Sysvar<Clock>) -> bool {
        let first_period = self.schedule.first().unwrap();
        let now = clock.unix_timestamp as u64;

        first_period.start_ts <= now
    }

    fn apply_change(&mut self, change: Change) {
        match change {
            Change::Update { index, period } => {
                self.schedule[index as usize] = period;
            }
            Change::Remove { index } => {
                self.schedule.remove(index as usize);
            }
            Change::Push { period } => {
                self.schedule.push(period);
            }
        }
    }

    fn bps_available_to_claim(&self, now: u64, user_details: &UserDetails) -> (Decimal, Decimal) {
        let mut total_percentage_to_claim = Decimal::ZERO;
        let mut total_percentage_to_add = Decimal::ZERO;

        for period in self.schedule.iter() {
            sol_log_64(now, period.start_ts, user_details.last_claimed_at_ts, 0, 0);

            if now < period.start_ts {
                sol_log("too early to claim period");
                break;
            }

            let period_end_ts = period.start_ts + period.times * period.interval_sec;
            if period_end_ts <= user_details.last_claimed_at_ts {
                sol_log("skip since we've already claimed");
                continue;
            }

            if period.airdropped {
                sol_log("this period was airdropped");
                total_percentage_to_add += Decimal::new(period.token_percentage as i64, 4);
                continue;
            }

            let last_claimed_at_ts_aligned_by_interval = user_details.last_claimed_at_ts
                - user_details.last_claimed_at_ts % period.interval_sec;
            let seconds_passed =
                now - std::cmp::max(period.start_ts, last_claimed_at_ts_aligned_by_interval);
            let intervals_passed = seconds_passed / period.interval_sec;
            let intervals_passed = std::cmp::min(intervals_passed, period.times);

            sol_log_64(
                user_details.last_claimed_at_ts,
                last_claimed_at_ts_aligned_by_interval,
                seconds_passed,
                now,
                intervals_passed,
            );

            let percentage_for_intervals =
                (Decimal::new(period.token_percentage as i64, DECIMALS + 2)
                    / Decimal::from_u64(period.times).unwrap())
                    * Decimal::from_u64(intervals_passed).unwrap();

            total_percentage_to_claim += percentage_for_intervals;
        }

        (total_percentage_to_claim, total_percentage_to_add)
    }
}

#[account]
#[derive(Debug)]
pub struct MerkleDistributor {
    merkle_index: u64,
    merkle_root: [u8; 32],
    paused: bool,
    vault_bump: u8,
    vault: Pubkey,
    vesting: Vesting,
}

impl MerkleDistributor {
    pub fn space_required(periods: &[Period]) -> usize {
        8 + std::mem::size_of::<Self>() + periods.len() * std::mem::size_of::<Period>()
    }
}

#[derive(Accounts)]
#[instruction(bump: u8)]
pub struct InitUserDetails<'info> {
    #[account(mut)]
    payer: Signer<'info>,
    /// CHECK:
    user: AccountInfo<'info>,
    #[account(
        init,
        payer = payer,
        space = UserDetails::LEN,
        seeds = [
            distributor.key().as_ref(),
            distributor.merkle_index.to_be_bytes().as_ref(),
            user.key().as_ref(),
        ],
        bump,
    )]
    user_details: Account<'info, UserDetails>,
    distributor: Account<'info, MerkleDistributor>,

    system_program: Program<'info, System>,
}

#[derive(Accounts)]
#[instruction(bump: u8)]
pub struct InitializeConfig<'info> {
    #[account(mut)]
    owner: Signer<'info>,

    #[account(
        init,
        payer = owner,
        space = Config::LEN,
        seeds = [
            "config".as_ref()
        ],
        bump,
    )]
    config: Account<'info, Config>,

    system_program: Program<'info, System>,
}

#[derive(AnchorDeserialize, AnchorSerialize)]
pub struct InitializeArgs {
    pub vault_bump: u8,
    pub merkle_root: [u8; 32],
    pub schedule: Vec<Period>,
}

#[derive(Accounts)]
#[instruction(args: InitializeArgs)]
pub struct Initialize<'info> {
    #[account(
        seeds = [
            "config".as_ref()
        ],
        bump
    )]
    config: Account<'info, Config>,
    #[account(
        mut,
        constraint = admin_or_owner.key() == config.owner ||
            config.admins.contains(&Some(admin_or_owner.key()))
            @ ErrorCode::NotAdminOrOwner
    )]
    admin_or_owner: Signer<'info>,

    #[account(
        init,
        payer = admin_or_owner,
        space = MerkleDistributor::space_required(&args.schedule),
    )]
    distributor: Account<'info, MerkleDistributor>,

    /// CHECK:
    #[account(
        seeds = [
            distributor.key().as_ref()
        ],
        bump = args.vault_bump
    )]
    vault_authority: AccountInfo<'info>,
    #[account(constraint = vault.owner == vault_authority.key())]
    vault: Account<'info, TokenAccount>,

    system_program: Program<'info, System>,
}

#[derive(AnchorSerialize, AnchorDeserialize)]
pub struct UpdateRootArgs {
    merkle_root: [u8; 32],
    unpause: bool,
}

#[derive(Accounts)]
pub struct UpdateRoot<'info> {
    #[account(mut)]
    distributor: Account<'info, MerkleDistributor>,
    #[account(
        seeds = [
            "config".as_ref()
        ],
        bump = config.bump
    )]
    config: Account<'info, Config>,
    #[account(
        constraint = admin_or_owner.key() == config.owner ||
            config.admins.contains(&Some(admin_or_owner.key()))
            @ ErrorCode::NotAdminOrOwner
    )]
    admin_or_owner: Signer<'info>,

    clock: Sysvar<'info, Clock>,
}

#[derive(AnchorDeserialize, AnchorSerialize)]
pub enum Change {
    Update { index: u64, period: Period },
    Remove { index: u64 },
    Push { period: Period },
}

#[derive(AnchorDeserialize, AnchorSerialize)]
pub struct UpdateScheduleArgs {
    changes: Vec<Change>,
}

#[derive(Accounts)]
pub struct UpdateSchedule<'info> {
    #[account(mut)]
    distributor: Account<'info, MerkleDistributor>,
    #[account(
        seeds = [
            "config".as_ref()
        ],
        bump = config.bump
    )]
    config: Account<'info, Config>,
    #[account(
        constraint = admin_or_owner.key() == config.owner ||
            config.admins.contains(&Some(admin_or_owner.key()))
            @ ErrorCode::NotAdminOrOwner
    )]
    admin_or_owner: Signer<'info>,

    clock: Sysvar<'info, Clock>,
}

#[derive(Accounts)]
pub struct SetPaused<'info> {
    #[account(mut)]
    distributor: Account<'info, MerkleDistributor>,
    #[account(
        seeds = [
            "config".as_ref()
        ],
        bump = config.bump
    )]
    config: Account<'info, Config>,
    #[account(
        constraint = admin_or_owner.key() == config.owner ||
            config.admins.contains(&Some(admin_or_owner.key()))
            @ ErrorCode::NotAdminOrOwner
    )]
    admin_or_owner: Signer<'info>,
}

#[derive(Accounts)]
pub struct AddAdmin<'info> {
    #[account(
        mut,
        seeds = [
            "config".as_ref()
        ],
        bump = config.bump
    )]
    config: Account<'info, Config>,
    #[account(
        constraint = owner.key() == config.owner
            @ ErrorCode::NotOwner
    )]
    owner: Signer<'info>,
    /// CHECK:
    admin: AccountInfo<'info>,
}

#[derive(Accounts)]
pub struct RemoveAdmin<'info> {
    #[account(
        mut,
        seeds = [
            "config".as_ref()
        ],
        bump = config.bump
    )]
    config: Account<'info, Config>,
    #[account(
        constraint = owner.key() == config.owner
            @ ErrorCode::NotOwner
    )]
    owner: Signer<'info>,
    /// CHECK:
    admin: AccountInfo<'info>,
}

#[derive(Accounts)]
pub struct WithdrawTokens<'info> {
    distributor: Account<'info, MerkleDistributor>,
    #[account(
        seeds = [
            "config".as_ref()
        ],
        bump = config.bump
    )]
    config: Account<'info, Config>,
    #[account(
        constraint = owner.key() == config.owner
            @ ErrorCode::NotOwner
    )]
    owner: Signer<'info>,

    /// CHECK:
    #[account(
        seeds = [
            distributor.key().as_ref()
        ],
        bump = distributor.vault_bump
    )]
    vault_authority: AccountInfo<'info>,
    #[account(
        mut,
        constraint = vault.owner == vault_authority.key()
    )]
    vault: Account<'info, TokenAccount>,
    #[account(
        mut,
        constraint = vault.mint == target_wallet.mint
    )]
    target_wallet: Account<'info, TokenAccount>,

    token_program: Program<'info, Token>,
}

#[derive(AnchorSerialize, AnchorDeserialize)]
pub struct ClaimArgs {
    amount: u64,
    merkle_proof: Vec<[u8; 32]>,
}

#[derive(Accounts)]
#[instruction(args: ClaimArgs)]
pub struct Claim<'info> {
    distributor: Account<'info, MerkleDistributor>,
    user: Signer<'info>,
    #[account(
        mut,
        seeds = [
            distributor.key().as_ref(),
            distributor.merkle_index.to_be_bytes().as_ref(),
            user.key().as_ref(),
        ],
        bump = user_details.bump
    )]
    user_details: Account<'info, UserDetails>,

    /// CHECK:
    #[account(
        seeds = [
            distributor.key().as_ref()
        ],
        bump = distributor.vault_bump
    )]
    vault_authority: AccountInfo<'info>,
    #[account(
        mut,
        constraint = vault.owner == vault_authority.key()
    )]
    vault: Account<'info, TokenAccount>,
    #[account(
        mut,
        constraint = vault.mint == target_wallet.mint
    )]
    target_wallet: Account<'info, TokenAccount>,

    token_program: Program<'info, Token>,
    clock: Sysvar<'info, Clock>,
}

struct TokenTransfer<'pay, 'info> {
    amount: u64,
    from: &'pay mut Account<'info, TokenAccount>,
    to: &'pay Account<'info, TokenAccount>,
    authority: &'pay AccountInfo<'info>,
    token_program: &'pay Program<'info, Token>,
    signers: Option<&'pay [&'pay [&'pay [u8]]]>,
}

impl TokenTransfer<'_, '_> {
    fn make(self) -> Result<()> {
        let amount_before = self.from.amount;

        self.from.key().log();
        self.to.key().log();
        self.authority.key().log();

        let cpi_ctx = CpiContext::new(
            self.token_program.to_account_info(),
            Transfer {
                from: self.from.to_account_info(),
                to: self.to.to_account_info(),
                authority: self.authority.to_account_info(),
            },
        );
        let cpi_ctx = match self.signers {
            Some(signers) => cpi_ctx.with_signer(signers),
            None => cpi_ctx,
        };

        token::transfer(cpi_ctx, self.amount)?;

        self.from.reload()?;
        let amount_after = self.from.amount;

        sol_log_64(amount_before, amount_after, self.amount, 0, 0);

        require!(
            amount_before - amount_after == self.amount,
            InvalidAmountTransferred
        );

        Ok(())
    }
}

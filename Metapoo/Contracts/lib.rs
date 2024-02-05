use {
    anchor_lang::prelude::*,
    anchor_spl::{
        associated_token::AssociatedToken,
        token::{self, Mint, CloseAccount, Token, TokenAccount, Transfer},
    },
    metaplex_token_metadata::state::Edition
};

// set the program's public key
declare_id!("4Zqz7sSAxU4qtvHNdyYQ4J2KGDM7oqAhXLYDkpeFSvJR");

const POOL_IMPRINT: &[u8] = b"imprint";
const POOL_LP_ACCOUNT_SEED: &[u8] = b"pool_lp_account";
const POOL_REWARD_ACCOUNT_SEED: &[u8] = b"pool_reward_account";

#[program]
pub mod farm {
    use super::*;

    #[access_control(
        InitializePool::check_pool(
            start_block,
            end_block,
            reward_per_block
        )
    )]
    pub fn initialize_pool(ctx: Context<InitializePool>,
        _seed: String,
        imprint_bump: u8,
        start_block: i64,
        end_block: i64,
        reward_per_block: u64,
    ) -> ProgramResult {
        let pool_account = &mut ctx.accounts.pool_account.load_init()?;

        pool_account.owner = ctx.accounts.owner.key();
        pool_account.imprint = ctx.accounts.imprint.key();
        pool_account.lp_mint = ctx.accounts.lp_mint.key();
        pool_account.pool_lp_account = ctx.accounts.pool_lp_account.key();
        pool_account.reward_mint = ctx.accounts.reward_mint.key();
        pool_account.pool_reward_account = ctx.accounts.pool_reward_account.key();

        pool_account.precision_factor = u64::pow(10, ctx.accounts.lp_mint.decimals as u32);

        pool_account.master_nft_counter = 0;

        pool_account.imprint_bump = imprint_bump;

        // transfer reward to farm
        let total_time = end_block
            .checked_sub(start_block)
            .ok_or(ErrorCode::AmountCalculationFailure)? as u64;
        let total_reward = reward_per_block
            .checked_mul(total_time)
            .ok_or(ErrorCode::AmountCalculationFailure)?;

        let cpi_ctx = CpiContext::new(
            ctx.accounts.token_program.to_account_info(),
            token::Transfer {
                from: ctx.accounts.owner_reward_account.to_account_info(),
                to: ctx.accounts.pool_reward_account.to_account_info(),
                authority: ctx.accounts.owner.to_account_info(),
            },
        );

        token::transfer(cpi_ctx, total_reward)?;

        pool_account.supply = 0;
        pool_account.start_block = start_block;
        pool_account.end_block = end_block;
        pool_account.acc_token_per_share = 0;
        pool_account.last_reward_block = start_block;
        pool_account.reward_per_block = reward_per_block;

        Ok(())
    }

    #[access_control(
        InitializePool::check_pool(
            start_block,
            end_block,
            reward_per_block
        )
    )]
    pub fn update_pool(
        ctx: Context<UpdatePool>,
        start_block: i64,
        end_block: i64,
        reward_per_block: u64
    ) -> ProgramResult {
        let mut pool_account = ctx.accounts.pool_account.load_mut()?;

        pool_account.allow_update()?;

        pool_account.start_block = start_block;
        pool_account.end_block = end_block;
        pool_account.reward_per_block = reward_per_block;
        pool_account.last_reward_block = start_block;

        Ok(())
    }

    pub fn close_pool(ctx: Context<ClosePoolRequest>) -> ProgramResult {
        let pool_account = ctx.accounts.pool_account.load()?;

        if pool_account.supply == 0 {
            pool_account.close_token(
                ctx.accounts.token_program.to_account_info(),
                ctx.accounts.pool_lp_account.to_account_info(),
                ctx.accounts.owner.to_account_info(),
                ctx.accounts.imprint.to_account_info(),
                &ctx.accounts.pool_account.key(),
            )?;

            pool_account.close_token(
                ctx.accounts.token_program.to_account_info(),
                ctx.accounts.pool_reward_account.to_account_info(),
                ctx.accounts.owner.to_account_info(),
                ctx.accounts.imprint.to_account_info(),
                &ctx.accounts.pool_account.key(),
            )?;

            Ok(())
        }
        else {
            Err(ErrorCode::PoolHasNotEnded.into())
        }
    }

    pub fn owner_withdraw_reward(ctx: Context<OwnerWithdrawRewardRequest>) -> ProgramResult {
        let pool_account = ctx.accounts.pool_account.load()?;

        if pool_account.supply == 0 {
            pool_account.send_token(
                ctx.accounts.token_program.to_account_info(),
                ctx.accounts.pool_reward_account.to_account_info(),
                ctx.accounts.owner_reward_account.to_account_info(),
                ctx.accounts.imprint.to_account_info(),
                ctx.accounts.pool_account.to_account_info().key,
                ctx.accounts.pool_reward_account.amount
            )
        }
        else {
            Err(ErrorCode::PoolHasNotEnded.into())
        }
    }

    pub fn add_master_nft(
        ctx: Context<AddMasterNFTRequest>,
        boost: u8,
        maximum_energy: u64
    ) -> ProgramResult {
        if boost <= 100 {
            let mut pool_account = ctx.accounts.pool_account.load_mut()?;
            if pool_account.master_nft_counter < 3 {
                let master_nft = MasterNFT {
                    master_mint: ctx.accounts.master_mint.key(),
                    boost,
                    maximum_energy
                };

                let position = pool_account.master_nft_counter as usize;
                pool_account.master_nfts[position] = master_nft;
                pool_account.master_nft_counter += 1;

                Ok(())
            }
            else {
                Err(ErrorCode::ReachToMaximumShouldBe.into())
            }
        }
        else {
            Err(ErrorCode::InvalidBoostValue.into())
        }
    }

    pub fn initialize_member(
        ctx: Context<InitializeMember>
    ) -> ProgramResult {
        let pool_account = ctx.accounts.pool_account.load()?;
        pool_account.allow_deposit()?;

        let mut member = ctx.accounts.member.load_init()?;
        member.user = ctx.accounts.user.key();
        member.lp_amount = 0;
        member.reward_debt = 0;
        member.nft = None;

        Ok(())
    }

    pub fn deposit(
        ctx: Context<DepositRequest>,
        amount: u64
    ) -> ProgramResult {
        if amount > 0 {
            let mut pool_account = ctx.accounts.pool_account.load_mut()?;

            pool_account.allow_deposit()?;
            pool_account.update_state()?;

            let mut member = ctx.accounts.member.load_mut()?;

            if member.lp_amount > 0 {
                if let Some((pending_reward, boosted_reward)) = member.cal_pending_reward(*pool_account) {
                    pool_account.send_token(
                        ctx.accounts.token_program.to_account_info(),
                        ctx.accounts.pool_reward_account.to_account_info(),
                        ctx.accounts.user_reward_account.to_account_info(),
                        ctx.accounts.imprint.to_account_info(),
                        ctx.accounts.pool_account.to_account_info().key,
                        pending_reward
                    )?;

                    if let Some(boosted_reward) = boosted_reward {
                        member.update_remaining_energy(boosted_reward)?;
                    }
                }
            }

            let cpi_accounts = token::Transfer {
                from: ctx.accounts.user_lp_account.to_account_info(),
                to: ctx.accounts.pool_lp_account.to_account_info(),
                authority: ctx.accounts.user.to_account_info()
            };
            let cpi_ctx = CpiContext::new(ctx.accounts.token_program.to_account_info(), cpi_accounts);
            token::transfer(cpi_ctx, amount)?;

            pool_account.supply = pool_account.supply
                .checked_add(amount)
                .ok_or(ErrorCode::AmountCalculationFailure)?;

            member.lp_amount = member.lp_amount
                .checked_add(amount)
                .ok_or(ErrorCode::AmountCalculationFailure)?;

            member.update_reward_debt(pool_account.acc_token_per_share, pool_account.precision_factor)?;

            Ok(())
        }
        else {
            Err(ErrorCode::InvalidDepositAmount.into())
        }
    }

    pub fn boost(ctx: Context<BoostRequest>) -> ProgramResult {
        let mut pool_account = ctx.accounts.pool_account.load_mut()?;
        pool_account.allow_deposit()?;

        let mut member = ctx.accounts.member.load_mut()?;

        if member.lp_amount == 0 {
            return Err(ErrorCode::NotDeposited.into());
        }

        if member.nft.is_some() {
            return Err(ErrorCode::NftAlreadyStaked.into());
        }

        // Validation edition
        let user_nft_edition = &ctx.accounts.user_nft_edition;
        metaplex_token_metadata::utils::assert_edition_valid(
            &metaplex_token_metadata::id(),
            &ctx.accounts.user_nft_mint.key(),
            user_nft_edition
        )?;

        metaplex_token_metadata::utils::assert_edition_valid(
            &metaplex_token_metadata::id(),
            ctx.accounts.master_mint.key,
            &ctx.accounts.master_edition
        )?;

        // validation by master_edition
        let user_edition = Edition::from_account_info(user_nft_edition)?;

        if user_edition.parent == ctx.accounts.master_edition.key() {
            if let Some(master_nft) = pool_account.find_master_nft(ctx.accounts.master_mint.key) {
                // Pending reward
                if member.lp_amount > 0 {
                    pool_account.update_state()?;

                    if let Some((pending_reward, _)) = member.cal_pending_reward(*pool_account) {
                        pool_account.send_token(
                            ctx.accounts.token_program.to_account_info(),
                            ctx.accounts.pool_reward_account.to_account_info(),
                            ctx.accounts.user_reward_account.to_account_info(),
                            ctx.accounts.imprint.to_account_info(),
                            ctx.accounts.pool_account.to_account_info().key,
                            pending_reward
                        )?;

                        member.update_reward_debt(pool_account.acc_token_per_share, pool_account.precision_factor)?;
                    }
                }

                // Transfer nft to pool
                token::transfer(
                    CpiContext::new(
                        ctx.accounts.token_program.to_account_info(),
                        token::Transfer {
                            from: ctx.accounts.user_nft_token_account.to_account_info(),
                            to: ctx.accounts.pool_nft_token_account.to_account_info(),
                            authority: ctx.accounts.user.to_account_info(),
                        },
                    ),
                    1
                )?;

                member.nft = Some(UserNft {
                    user_nft_token_account: ctx.accounts.user_nft_token_account.key(),
                    pool_nft_token_account: ctx.accounts.pool_nft_token_account.key(),
                    master_mint: master_nft.master_mint,
                    remaining_energy: master_nft.maximum_energy
                });

                Ok(())
            }
            else {
                Err(ErrorCode::InvalidNftEdition.into())
            }
        }
        else {
            Err(ErrorCode::InvalidNftEdition.into())
        }
    }

    pub fn unboost(ctx: Context<UnboostRequest>) -> ProgramResult {
        let mut member = ctx.accounts.member.load_mut()?;

        if member.nft.is_none() {
            return Err(ErrorCode::NftAlreadyUnstaked.into());
        }

        if (ctx.accounts.user_nft_token_account.key() != member.nft.unwrap().user_nft_token_account) ||
           (ctx.accounts.pool_nft_token_account.key() != member.nft.unwrap().pool_nft_token_account) {
            return Err(ErrorCode::InvalidNftTokenAccount.into());
        }

        if member.lp_amount > 0 {
            let mut pool_account = ctx.accounts.pool_account.load_mut()?;

            pool_account.update_state()?;

            if let Some((pending_reward, _)) = member.cal_pending_reward(*pool_account) {
                pool_account.send_token(
                    ctx.accounts.token_program.to_account_info(),
                    ctx.accounts.pool_reward_account.to_account_info(),
                    ctx.accounts.user_reward_account.to_account_info(),
                    ctx.accounts.imprint.to_account_info(),
                    ctx.accounts.pool_account.to_account_info().key,
                    pending_reward
                )?;

                member.update_reward_debt(pool_account.acc_token_per_share, pool_account.precision_factor)?;
            }

            member.nft = None;

            // transfer nft to user
            pool_account.send_token(
                ctx.accounts.token_program.to_account_info(),
                ctx.accounts.pool_nft_token_account.to_account_info(),
                ctx.accounts.user_nft_token_account.to_account_info(),
                ctx.accounts.imprint.to_account_info(),
                ctx.accounts.pool_account.to_account_info().key,
                1
            )?;

            // Close pool token account
            pool_account.close_token(
                ctx.accounts.token_program.to_account_info(),
                ctx.accounts.pool_nft_token_account.to_account_info(),
                ctx.accounts.user.to_account_info(),
                ctx.accounts.imprint.to_account_info(),
                &ctx.accounts.pool_account.key()
            )?;

            Ok(())
        }
        else {
            Err(ErrorCode::InsufficientReward.into())
        }
    }

    pub fn earn_reward(ctx: Context<EarnRewardRequest>) -> ProgramResult {
        let mut member = ctx.accounts.member.load_mut()?;

        if member.lp_amount > 0 {
            let mut pool_account = ctx.accounts.pool_account.load_mut()?;

            pool_account.update_state()?;

            if let Some((pending_reward, boosted_reward)) = member.cal_pending_reward(*pool_account) {
                pool_account.send_token(
                    ctx.accounts.token_program.to_account_info(),
                    ctx.accounts.pool_reward_account.to_account_info(),
                    ctx.accounts.user_reward_account.to_account_info(),
                    ctx.accounts.imprint.to_account_info(),
                    ctx.accounts.pool_account.to_account_info().key,
                    pending_reward
                )?;

                if let Some(boosted_reward) = boosted_reward {
                    member.update_remaining_energy(boosted_reward)?;
                }

                member.update_reward_debt(pool_account.acc_token_per_share, pool_account.precision_factor)?;

                Ok(())
            }
            else {
                Err(ErrorCode::InsufficientReward.into())
            }
        }
        else {
            Err(ErrorCode::InsufficientReward.into())
        }
    }

    pub fn claim(ctx: Context<ClaimRequest>) -> ProgramResult {
        let mut member = ctx.accounts.member.load_mut()?;

        if member.nft.is_some() {
            Err(ErrorCode::NftAlreadyStaked.into())
        }
        else if member.lp_amount == 0 {
            Err(ErrorCode::WithdrawZero.into())
        }
        else {
            let mut pool_account = ctx.accounts.pool_account.load_mut()?;

            pool_account.update_state()?;

            let pending_reward = member.cal_pending_reward(*pool_account);

            pool_account.send_token(
                ctx.accounts.token_program.to_account_info(),
                ctx.accounts.pool_lp_account.to_account_info(),
                ctx.accounts.user_lp_account.to_account_info(),
                ctx.accounts.imprint.to_account_info(),
                ctx.accounts.pool_account.to_account_info().key,
                member.lp_amount
            )?;

            pool_account.supply = pool_account.supply
                .checked_sub(member.lp_amount)
                .ok_or(ErrorCode::AmountCalculationFailure)?;
            member.lp_amount = 0;

            // Claim Reward
            if let Some((pending_reward, _)) = pending_reward {
                pool_account.send_token(
                    ctx.accounts.token_program.to_account_info(),
                    ctx.accounts.pool_reward_account.to_account_info(),
                    ctx.accounts.user_reward_account.to_account_info(),
                    ctx.accounts.imprint.to_account_info(),
                    ctx.accounts.pool_account.to_account_info().key,
                    pending_reward
                )?;
            }

            member.update_reward_debt(pool_account.acc_token_per_share, pool_account.precision_factor)?;

            Ok(())
        }
    }

    pub fn claim_with_nft(ctx: Context<ClaimWithNftRequest>) -> ProgramResult {
        let mut member = ctx.accounts.member.load_mut()?;

        if member.nft.is_none() {
            Err(ErrorCode::NftAlreadyUnstaked.into())
        }
        else if (ctx.accounts.user_nft_token_account.key() != member.nft.unwrap().user_nft_token_account) ||
            (ctx.accounts.pool_nft_token_account.key() != member.nft.unwrap().pool_nft_token_account) {
            Err(ErrorCode::InvalidNftTokenAccount.into())
        }
        else if member.lp_amount == 0 {
            Err(ErrorCode::WithdrawZero.into())
        }
        else {
            let mut pool_account = ctx.accounts.pool_account.load_mut()?;

            pool_account.update_state()?;

            let pending_reward = member.cal_pending_reward(*pool_account);

            pool_account.send_token(
                ctx.accounts.token_program.to_account_info(),
                ctx.accounts.pool_lp_account.to_account_info(),
                ctx.accounts.user_lp_account.to_account_info(),
                ctx.accounts.imprint.to_account_info(),
                ctx.accounts.pool_account.to_account_info().key,
                member.lp_amount
            )?;

            pool_account.supply = pool_account.supply
                .checked_sub(member.lp_amount)
                .ok_or(ErrorCode::AmountCalculationFailure)?;
            member.lp_amount = 0;
            member.nft = None;

            // Claim Reward
            if let Some((pending_reward, _)) = pending_reward {
                pool_account.send_token(
                    ctx.accounts.token_program.to_account_info(),
                    ctx.accounts.pool_reward_account.to_account_info(),
                    ctx.accounts.user_reward_account.to_account_info(),
                    ctx.accounts.imprint.to_account_info(),
                    ctx.accounts.pool_account.to_account_info().key,
                    pending_reward
                )?;
            }

            // transfer nft to user
            pool_account.send_token(
                ctx.accounts.token_program.to_account_info(),
                ctx.accounts.pool_nft_token_account.to_account_info(),
                ctx.accounts.user_nft_token_account.to_account_info(),
                ctx.accounts.imprint.to_account_info(),
                ctx.accounts.pool_account.to_account_info().key,
                1
            )?;

            // Close pool token account
            pool_account.close_token(
                ctx.accounts.token_program.to_account_info(),
                ctx.accounts.pool_nft_token_account.to_account_info(),
                ctx.accounts.user.to_account_info(),
                ctx.accounts.imprint.to_account_info(),
                &ctx.accounts.pool_account.key()
            )?;

            member.update_reward_debt(pool_account.acc_token_per_share, pool_account.precision_factor)?;

            Ok(())
        }
    }
}

#[derive(Accounts)]
#[instruction(_seed: String)]
pub struct InitializePool<'info> {
    #[account(
        init,
        seeds = [_seed.as_bytes()],
        bump,
        payer = owner
    )]
    pool_account: AccountLoader<'info, PoolAccount>,

    #[account(
        seeds = [
            pool_account.key().as_ref(),
            POOL_IMPRINT,
        ],
        bump
    )]
    imprint: AccountInfo<'info>,

    lp_mint: Account<'info, Mint>,
    #[account(
        init,
        token::mint = lp_mint,
        token::authority = imprint,
        seeds = [
            imprint.key().as_ref(),
            POOL_LP_ACCOUNT_SEED,
        ],
        bump,
        payer = owner
    )]
    pool_lp_account: Account<'info, TokenAccount>,

    reward_mint: AccountInfo<'info>,

    #[account(
        init,
        token::mint = reward_mint,
        token::authority = imprint,
        seeds = [
            imprint.key().as_ref(),
            POOL_REWARD_ACCOUNT_SEED,
        ],
        bump,
        payer = owner
    )]
    pool_reward_account: Account<'info, TokenAccount>,

    owner: Signer<'info>,

    #[account(
        mut,
        constraint = owner_reward_account.owner == owner.key()
    )]
    owner_reward_account: Account<'info, TokenAccount>,

    token_program: Program<'info, Token>,
    system_program: Program<'info, System>,
    rent: Sysvar<'info, Rent>
}

impl<'info> InitializePool<'info> {
    fn check_pool(start_block: i64, end_block: i64, reward_per_block: u64) -> ProgramResult {
        let clock = Clock::get()?;

        if start_block < clock.unix_timestamp {
            return Err(ErrorCode::InvalidStartBlock.into());
        }

        if end_block <= start_block {
            return Err(ErrorCode::InvalidExpiry.into());
        }

        if reward_per_block == 0 {
            return Err(ErrorCode::InvalidRewardPerBlock.into());
        }

        Ok(())
    }
}

#[derive(Accounts)]
pub struct UpdatePool<'info> {
    #[account(
        mut,
        has_one = owner
    )]
    pool_account: AccountLoader<'info, PoolAccount>,

    owner: Signer<'info>,
}

#[derive(Accounts)]
pub struct ClosePoolRequest<'info> {
    owner: Signer<'info>,

    #[account(
        mut,
        close = owner,
        has_one = owner,
        has_one = imprint,
        has_one = pool_lp_account,
        has_one = pool_reward_account
    )]
    pool_account: AccountLoader<'info, PoolAccount>,
    imprint: AccountInfo<'info>,

    #[account(mut)]
    pool_lp_account: AccountInfo<'info>,
    #[account(mut)]
    pool_reward_account: AccountInfo<'info>,

    token_program: Program<'info, Token>,
}

#[derive(Accounts)]
pub struct AddMasterNFTRequest<'info> {
    #[account(
        mut,
        has_one = owner
    )]
    pool_account: AccountLoader<'info, PoolAccount>,

    owner: Signer<'info>,
    master_mint: AccountInfo<'info>
}

#[derive(Accounts)]
pub struct RemoveMasterNFTRequest<'info> {
    #[account(
        mut,
        has_one = owner
    )]
    pool_account: AccountLoader<'info, PoolAccount>,

    owner: Signer<'info>,
    master_mint: AccountInfo<'info>
}

#[derive(Accounts)]
pub struct InitializeMember<'info> {
    pool_account: AccountLoader<'info, PoolAccount>,
    user: Signer<'info>,

    #[account(
        init,
        seeds = [
            pool_account.key().as_ref(),
            user.key.as_ref()
        ],
        bump,
        payer = user,
        space = 161
    )]
    member: AccountLoader<'info, Member>,

    system_program: Program<'info, System>
}

#[derive(Accounts)]
pub struct DepositRequest<'info> {
    #[account(
        mut,
        has_one = imprint,
        has_one = reward_mint,
        has_one = pool_lp_account,
        has_one = pool_reward_account,
    )]
    pool_account: AccountLoader<'info, PoolAccount>,
    imprint: AccountInfo<'info>,

    #[account(mut)]
    pool_lp_account: AccountInfo<'info>,

    reward_mint: AccountInfo<'info>,
    #[account(mut)]
    pool_reward_account: AccountInfo<'info>,

    user: Signer<'info>,

    #[account(
        mut,
        seeds = [
            pool_account.key().as_ref(),
            user.key.as_ref()
        ],
        bump,
        has_one = user
    )]
    member: AccountLoader<'info, Member>,

    #[account(
        mut,
        constraint = user_lp_account.owner == user.key()
    )]
    user_lp_account: Account<'info, TokenAccount>,

    #[account(
        init_if_needed,
        associated_token::mint = reward_mint,
        associated_token::authority = user,
        payer = user,
        constraint = user_reward_account.owner == user.key()
    )]
    user_reward_account: Account<'info, TokenAccount>,

    token_program: Program<'info, Token>,
    associated_token_program: Program<'info, AssociatedToken>,
    system_program: Program<'info, System>,
    rent: Sysvar<'info, Rent>
}

#[derive(Accounts)]
pub struct BoostRequest<'info> {
    #[account(
        mut,
        has_one = imprint,
        has_one = pool_reward_account,
    )]
    pool_account: AccountLoader<'info, PoolAccount>,
    imprint: AccountInfo<'info>,

    #[account(mut)]
    pool_reward_account: AccountInfo<'info>,

    master_mint: AccountInfo<'info>,
    master_edition: AccountInfo<'info>,

    #[account(
        init,
        associated_token::mint = user_nft_mint,
        associated_token::authority = imprint,
        payer = user
    )]
    pool_nft_token_account: Account<'info, TokenAccount>,

    user: Signer<'info>,

    #[account(
        mut,
        seeds = [
            pool_account.key().as_ref(),
            user.key().as_ref()
        ],
        bump,
        has_one = user
    )]
    member: AccountLoader<'info, Member>,

    #[account(
        mut,
        // constraint = user_reward_account.owner == user.key()
    )]
    user_reward_account: AccountInfo<'info>,

    user_nft_edition: AccountInfo<'info>,
    user_nft_mint: AccountInfo<'info>,

    #[account(
        mut,
        constraint = user_nft_token_account.mint == user_nft_mint.key(),
        constraint = user_nft_token_account.owner == user.key()
    )]
    user_nft_token_account: Account<'info, TokenAccount>,

    #[account(
        init,
        seeds = [
            pool_account.key().as_ref(),
            user_nft_mint.key().as_ref()
        ],
        bump,
        payer = user
    )]
    boosted_nft: Account<'info, BoostedNft>,

    token_program: Program<'info, Token>,
    associated_token_program: Program<'info, AssociatedToken>,
    system_program: Program<'info, System>,
    rent: Sysvar<'info, Rent>,
}

#[derive(Accounts)]
pub struct UnboostRequest<'info> {
    #[account(
        mut,
        has_one = imprint,
        has_one = reward_mint,
        has_one = pool_reward_account,
    )]
    pool_account: AccountLoader<'info, PoolAccount>,
    imprint: AccountInfo<'info>,

    reward_mint: AccountInfo<'info>,
    #[account(mut)]
    pool_reward_account: AccountInfo<'info>,

    #[account(mut)]
    pool_nft_token_account: AccountInfo<'info>,

    user: Signer<'info>,

    #[account(
        mut,
        seeds = [
            pool_account.key().as_ref(),
            user.key.as_ref()
        ],
        bump,
        has_one = user
    )]
    member: AccountLoader<'info, Member>,

    #[account(
        init_if_needed,
        associated_token::mint = reward_mint,
        associated_token::authority = user,
        payer = user,
        constraint = user_reward_account.owner == user.key()
    )]
    user_reward_account: Account<'info, TokenAccount>,

    #[account(mut)]
    user_nft_token_account: AccountInfo<'info>,

    token_program: Program<'info, Token>,
    associated_token_program: Program<'info, AssociatedToken>,
    system_program: Program<'info, System>,
    rent: Sysvar<'info, Rent>
}

#[derive(Accounts)]
pub struct EarnRewardRequest<'info> {
    #[account(
        mut,
        has_one = imprint,
        has_one = reward_mint,
        has_one = pool_reward_account,
    )]
    pool_account: AccountLoader<'info, PoolAccount>,
    imprint: AccountInfo<'info>,

    reward_mint: AccountInfo<'info>,
    #[account(mut)]
    pool_reward_account: AccountInfo<'info>,

    user: Signer<'info>,

    #[account(
        mut,
        seeds = [
            pool_account.key().as_ref(),
            user.key.as_ref()
        ],
        bump,
        has_one = user
    )]
    member: AccountLoader<'info, Member>,

    #[account(
        init_if_needed,
        associated_token::mint = reward_mint,
        associated_token::authority = user,
        payer = user,
        constraint = user_reward_account.owner == user.key()
    )]
    user_reward_account: Account<'info, TokenAccount>,

    token_program: Program<'info, Token>,
    associated_token_program: Program<'info, AssociatedToken>,
    system_program: Program<'info, System>,
    rent: Sysvar<'info, Rent>
}

#[derive(Accounts)]
pub struct ClaimRequest<'info> {
    #[account(
        mut,
        has_one = imprint,
        has_one = reward_mint,
        has_one = pool_lp_account,
        has_one = pool_reward_account
    )]
    pool_account: AccountLoader<'info, PoolAccount>,
    imprint: AccountInfo<'info>,

    #[account(mut)]
    pool_lp_account: AccountInfo<'info>,

    reward_mint: AccountInfo<'info>,
    #[account(mut)]
    pool_reward_account: AccountInfo<'info>,

    user: Signer<'info>,

    #[account(
        mut,
        close = user,
        seeds = [
            pool_account.key().as_ref(),
            user.key.as_ref()
        ],
        bump,
        has_one = user
    )]
    member: AccountLoader<'info, Member>,

    #[account(
        mut,
        constraint = user_lp_account.owner == user.key()
    )]
    user_lp_account: Account<'info, TokenAccount>,

    #[account(
        init_if_needed,
        associated_token::mint = reward_mint,
        associated_token::authority = user,
        payer = user,
        constraint = user_reward_account.owner == user.key()
    )]
    user_reward_account: Account<'info, TokenAccount>,

    token_program: Program<'info, Token>,
    associated_token_program: Program<'info, AssociatedToken>,
    system_program: Program<'info, System>,
    rent: Sysvar<'info, Rent>
}

#[derive(Accounts)]
pub struct ClaimWithNftRequest<'info> {
    #[account(
        mut,
        has_one = imprint,
        has_one = pool_lp_account,
        has_one = pool_reward_account
    )]
    pool_account: AccountLoader<'info, PoolAccount>,
    imprint: AccountInfo<'info>,

    #[account(mut)]
    pool_lp_account: AccountInfo<'info>,

    reward_mint: AccountInfo<'info>,
    #[account(mut)]
    pool_reward_account: AccountInfo<'info>,

    #[account(mut)]
    pool_nft_token_account: AccountInfo<'info>,

    user: Signer<'info>,

    #[account(
        mut,
        close = user,
        seeds = [
            pool_account.key().as_ref(),
            user.key.as_ref()
        ],
        bump,
        has_one = user
    )]
    member: AccountLoader<'info, Member>,

    #[account(
        mut,
        constraint = user_lp_account.owner == user.key()
    )]
    user_lp_account: Account<'info, TokenAccount>,

    #[account(
        init_if_needed,
        associated_token::mint = reward_mint,
        associated_token::authority = user,
        payer = user,
        constraint = user_reward_account.owner == user.key()
    )]
    user_reward_account: Account<'info, TokenAccount>,

    #[account(mut)]
    user_nft_token_account: AccountInfo<'info>,

    token_program: Program<'info, Token>,
    associated_token_program: Program<'info, AssociatedToken>,
    system_program: Program<'info, System>,
    rent: Sysvar<'info, Rent>
}

#[derive(Accounts)]
pub struct OwnerWithdrawRewardRequest<'info> {
    #[account(
        mut,
        has_one = owner,
        has_one = imprint,
        has_one = pool_reward_account
    )]
    pool_account: AccountLoader<'info, PoolAccount>,
    imprint: AccountInfo<'info>,

    #[account(
        mut
    )]
    pool_reward_account: Account<'info, TokenAccount>,

    owner: Signer<'info>,

    #[account(
        mut,
        constraint = owner_reward_account.mint == pool_account.load()?.reward_mint,
        constraint = owner_reward_account.owner == *owner.key
    )]
    owner_reward_account: Account<'info, TokenAccount>,

    token_program: Program<'info, Token>,
}

#[derive(Accounts)]
pub struct OwnerWithdrawLpRequest<'info> {
    #[account(
        mut,
        has_one = owner,
        has_one = imprint,
        has_one = pool_lp_account
    )]
    pool_account: AccountLoader<'info, PoolAccount>,
    imprint: AccountInfo<'info>,

    #[account(mut)]
    pool_lp_account: Account<'info, TokenAccount>,

    owner: Signer<'info>,

    #[account(
        mut,
        constraint = owner_lp_account.owner == owner.key()
    )]
    owner_lp_account: Account<'info, TokenAccount>,

    token_program: Program<'info, Token>,
}

#[zero_copy]
#[derive(Default)]
pub struct MasterNFT {
    pub master_mint: Pubkey,
    pub boost: u8, // boost <= 100
    pub maximum_energy: u64
}

#[account(zero_copy)]
#[derive(Default)]
pub struct PoolAccount {
    pub owner: Pubkey,
    pub imprint: Pubkey,
    pub lp_mint: Pubkey,
    pub pool_lp_account: Pubkey,
    pub reward_mint: Pubkey,
    pub pool_reward_account: Pubkey,

    pub precision_factor: u64,

    pub start_block: i64,
    pub end_block: i64,
    pub reward_per_block: u64,
    pub supply: u64,
    pub acc_token_per_share: u64,
    pub last_reward_block: i64,

    pub master_nft_counter: u8,
    pub master_nfts: [MasterNFT; 3],
    pub imprint_bump: u8,
}

impl PoolAccount {
    fn allow_deposit(&self) -> ProgramResult {
        let clock = Clock::get()?;

        if clock.unix_timestamp < self.start_block ||
        self.end_block < clock.unix_timestamp
        {
            return Err(ErrorCode::PoolHasEnded.into());
        }

        Ok(())
    }

    fn allow_update(&self) -> ProgramResult {
        let clock = Clock::get()?;

        if clock.unix_timestamp >= self.start_block {
            return Err(ErrorCode::PoolHasStarted.into());
        }

        Ok(())
    }

    fn find_master_nft(
        &self,
        master_mint: &Pubkey
    ) -> Option<MasterNFT> {
        for i in 0..self.master_nft_counter {
            if self.master_nfts[i as usize].master_mint == *master_mint {
                return Some(self.master_nfts[i as usize]);
            }
        }

        None
    }

    fn update_state(
        &mut self
    ) -> ProgramResult {
        let clock = Clock::get()?;

        if clock.unix_timestamp <= self.last_reward_block {
            return Ok(());
        }

        if self.supply == 0 {
            self.last_reward_block = clock.unix_timestamp;

            Ok(())
        }
        else {
            let multiplier = Self::get_multiplier(self.last_reward_block, clock.unix_timestamp, self.end_block);
            let token_reward = multiplier
                .checked_mul(self.reward_per_block)
                .ok_or(ErrorCode::AmountCalculationFailure)? as u128;

            let next_acc_token_per_share =
                token_reward
                    .checked_mul(self.precision_factor as u128)
                    .ok_or(ErrorCode::AmountCalculationFailure)?
                    .checked_div(self.supply as u128)
                    .ok_or(ErrorCode::AmountCalculationFailure)? as u64;

            self.acc_token_per_share = self.acc_token_per_share
                .checked_add(next_acc_token_per_share)
                .ok_or(ErrorCode::AmountCalculationFailure)?;

            self.last_reward_block = clock.unix_timestamp;

            Ok(())
        }
    }

    fn get_multiplier(from: i64, to: i64, end_block: i64) -> u64 {
        (
            if to <= end_block {
                to - from
            } else if from >= end_block {
                0
            } else {
                end_block - from
            }
        ) as u64
    }

    fn send_token<'info>(&self,
        token_program: AccountInfo<'info>,
        from: AccountInfo<'info>,
        to: AccountInfo<'info>,
        imprint: AccountInfo<'info>,
        pool_account: &Pubkey,
        amount: u64
    ) -> ProgramResult {
        let seeds = &[
            pool_account.as_ref(),
            POOL_IMPRINT,
            &[self.imprint_bump],
        ];
        let signer = &[&seeds[..]];

        let cpi_accounts = Transfer {
            from,
            to,
            authority: imprint,
        };

        let cpi_ctx = CpiContext::new_with_signer(token_program, cpi_accounts, signer);
        token::transfer(cpi_ctx, amount)?;

        Ok(())
    }

    fn close_token<'info>(&self,
        token_program: AccountInfo<'info>,
        from: AccountInfo<'info>,
        to: AccountInfo<'info>,
        imprint: AccountInfo<'info>,
        pool_account: &Pubkey,
    ) -> ProgramResult {
        let seeds = &[
            pool_account.as_ref(),
            POOL_IMPRINT,
            &[self.imprint_bump],
        ];
        let signer = &[&seeds[..]];

        let cpi_accounts = CloseAccount {
            account: from,
            destination: to,
            authority: imprint,
        };
        let cpi_ctx = CpiContext::new_with_signer(token_program, cpi_accounts, signer);
        token::close_account(cpi_ctx)?;

        Ok(())
    }
}

#[account]
#[derive(Default)]
pub struct BoostedNft {
}

#[zero_copy]
#[derive(Default)]
pub struct UserNft {
    pub user_nft_token_account: Pubkey,
    pub pool_nft_token_account: Pubkey,
    pub master_mint: Pubkey,
    pub remaining_energy: u64
}

#[account(zero_copy)]
pub struct Member {
    pub user: Pubkey,
    pub lp_amount: u64,
    pub reward_debt: u64,
    pub nft: Option<UserNft>
}

impl Member {
    fn cal_pending_reward(&self,
        pool_account: PoolAccount
    ) -> Option<(u64, Option<u64>)> {
        let mut pending_reward = (self.lp_amount as u128)
            .checked_mul(pool_account.acc_token_per_share as u128)
            .unwrap_or(0)
            .checked_div(pool_account.precision_factor as u128)
            .unwrap_or(0)
            .saturating_sub(self.reward_debt as u128) as u64;

        if pending_reward > 0 {
            if let Some(nft) = self.nft {
                // Cal boost reward here
                if let Some(master_nft) = pool_account.find_master_nft(&nft.master_mint) {
                    let mut boosted_reward = pending_reward
                        .checked_mul(master_nft.boost as u64)
                        .unwrap_or(0)
                        .checked_div(100)
                        .unwrap_or(0);

                    if boosted_reward > nft.remaining_energy {
                        boosted_reward = nft.remaining_energy;
                    }

                    if boosted_reward > 0 {
                        pending_reward = pending_reward
                            .checked_add(boosted_reward)
                            .unwrap_or(0);

                        return Some((pending_reward, Some(boosted_reward)));
                    }
                    else {
                        return Some((pending_reward, None));
                    }
                }
                else {
                    return Some((pending_reward, None));
                }
            }
            else {
                return Some((pending_reward, None))
            }
        }

        None
    }

    fn update_remaining_energy(&mut self,
        boosted_reward: u64
    ) -> ProgramResult {
        if let Some(mut nft) = self.nft {
            nft.remaining_energy = nft.remaining_energy
                .checked_sub(boosted_reward)
                .ok_or(ErrorCode::AmountCalculationFailure)?;

            self.nft = Some(nft);
        }

        Ok(())
    }

    fn update_reward_debt(&mut self,
        acc_token_per_share: u64,
        precision_factor: u64
    ) -> ProgramResult {
        let reward_debt = (self.lp_amount as u128)
            .checked_mul(acc_token_per_share as u128)
            .ok_or(ErrorCode::AmountCalculationFailure)?
            .checked_div(precision_factor as u128)
            .ok_or(ErrorCode::AmountCalculationFailure)?
            as u64;

        self.reward_debt = reward_debt;

        Ok(())
    }
}

#[error]
pub enum ErrorCode {
    #[msg("Invalid reward per block value")]
    InvalidRewardPerBlock,
    #[msg("Harvest amount equals Zero")]
    InsufficientReward,
    #[msg("Reward expiry must be after the current clock timestamp.")]
    InvalidExpiry,
    #[msg("Invalid start block")]
    InvalidStartBlock,
    #[msg("Pool hasn't ended")]
    PoolHasNotEnded,
    #[msg("Deposit amount should greater than Zero")]
    InvalidDepositAmount,
    #[msg("Withdrawal amount should greater than Zero")]
    WithdrawZero,
    #[msg("Pool has started")]
    PoolHasStarted,
    #[msg("Pool has ended")]
    PoolHasEnded,
    #[msg("Boost NFT has already been staked")]
    NftAlreadyStaked,
    #[msg("Must deposit before boosting")]
    NotDeposited,
    #[msg("Boost NFT has already been unstaked")]
    NftAlreadyUnstaked,
    #[msg("Invaliad NFT Token Account")]
    InvalidNftTokenAccount,
    #[msg("Invalid nft edition")]
    InvalidNftEdition,
    #[msg("Amount calculation failed due to overflow, underflow, or unexpected 0")]
    AmountCalculationFailure,
    #[msg("Boost percent must be between 0 and 100")]
    InvalidBoostValue,
    #[msg("Maximum reached")]
    ReachToMaximumShouldBe
}
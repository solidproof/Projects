//SPDX-License-Identifier: Unlicense

//              _     _                 _                _           _              _            _         _
//             /\ \  /\_\              / /\             /\ \        /\ \           /\ \     _   /\ \      /\ \
//            /  \ \/ / /         _   / /  \            \_\ \      /  \ \         /  \ \   /\_\/  \ \     \_\ \
//           / /\ \ \ \ \__      /\_\/ / /\ \           /\__ \    / /\ \ \       / /\ \ \_/ / / /\ \ \    /\__ \
//          / / /\ \ \ \___\    / / / / /\ \ \         / /_ \ \  / / /\ \ \     / / /\ \___/ / / /\ \_\  / /_ \ \
//         / / /  \ \_\__  /   / / / / /  \ \ \       / / /\ \ \/ / /  \ \_\   / / /  \/____/ /_/_ \/_/ / / /\ \ \
//        / / /   / / / / /   / / / / /___/ /\ \     / / /  \/_/ / /   / / /  / / /    / / / /____/\   / / /  \/_/
//       / / /   / / / / /   / / / / /_____/ /\ \   / / /     / / /   / / /  / / /    / / / /\____\/  / / /
//      / / /___/ / / / /___/ / / /_________/\ \ \ / / /     / / /___/ / _  / / /    / / / / /______ / / /
//     / / /____\/ / / /____\/ / / /_       __\ \_/_/ /     / / /____\/ /\_/ / /    / / / / /_______/_/ /
//    \/_________/\/_________/\_\___\     /____/_\_\/      \/_________/\/_\/_/     \/_/\/__________\_\/


pragma solidity 0.8.13;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";

contract OUATOnet is Initializable, Context, IERC20, IERC20Metadata, AccessControl {

    uint32 public liquidityFeePercentage;
    uint32 public productionFeePercentage;
    uint32 public platformFeePercentage;

    address public liquidityWallet;
    address public productionFeeWallet;
    address public platformFeeWallet;

    mapping(address => bool) public isExcludedFromFee;


    IUniswapV2Router02 private uniswapV2Router;
    address public uniswapV2Pair;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    uint16 public constant MULTIPLIER = 10000;

    bool private inSwapAndLiquify;

    mapping(address => uint256) private _balances;

    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private constant _name = "OUATO.net";
    string private constant _symbol = "$OUATO";

    uint256 public numTokensSellToAddToLiquidity = 1 * 10 ** 18;

    constructor() {
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(ADMIN_ROLE, _msgSender());
    }

    function initialize(uint32 liquidityFeePercentage_,
        uint32 productionFeePercentage_,
        uint32 platformFeePercentage_,
        address liquidityWallet_,
        address productionFeeWallet_,
        address platformFeeWallet_,
        address uniswapV2RouterAddress_) external initializer onlyRole(ADMIN_ROLE) {

        require(liquidityWallet_ != address(0), "liquidityWallet can not be zero address");
        require(productionFeeWallet_ != address(0), "productionFeeWallet can not be zero address");
        require(platformFeeWallet_ != address(0), "platformFeeWallet can not be zero address");

        _mint(_msgSender(), 1_000_000_000 * 10 ** decimals());
        liquidityFeePercentage = liquidityFeePercentage_;
        productionFeePercentage = productionFeePercentage_;
        platformFeePercentage = platformFeePercentage_;
        liquidityWallet = liquidityWallet_;
        productionFeeWallet = productionFeeWallet_;
        platformFeeWallet = platformFeeWallet_;

        uniswapV2Router = IUniswapV2Router02(uniswapV2RouterAddress_);
        // Create a uniswap pair for this new token
        uniswapV2Pair = IUniswapV2Factory(uniswapV2Router.factory()).createPair(address(this), uniswapV2Router.WETH());

        isExcludedFromFee[_msgSender()] = true;
        isExcludedFromFee[liquidityWallet] = true;
        isExcludedFromFee[address(this)] = true;
    }


    function changeFees(uint32 liquidityFeePercentage_, uint32 productionFeePercentage_, uint32 platformFeePercentage_) external onlyRole(ADMIN_ROLE) {
        liquidityFeePercentage = liquidityFeePercentage_;
        productionFeePercentage = productionFeePercentage_;
        platformFeePercentage = platformFeePercentage_;
    }

    function changeWallets(address liquidityWallet_, address productionFeeWallet_, address platformFeeWallet_) external onlyRole(ADMIN_ROLE) {
        require(liquidityWallet_ != address(0), "liquidityWallet can not be zero address");
        require(productionFeeWallet_ != address(0), "productionFeeWallet can not be zero address");
        require(platformFeeWallet_ != address(0), "platformFeeWallet can not be zero address");

        liquidityWallet = liquidityWallet_;
        productionFeeWallet = productionFeeWallet_;
        platformFeeWallet = platformFeeWallet_;
    }

    function updateNumTokensSellToAddToLiquidity(uint256 numTokensSellToAddToLiquidity_) external onlyRole(ADMIN_ROLE) {
        numTokensSellToAddToLiquidity = numTokensSellToAddToLiquidity_;
    }

    function swapTokensForEth(uint256 tokenAmount, address receiver) internal lockTheSwap {
        // generate the uniswap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();

        _approve(address(this), address(uniswapV2Router), tokenAmount);

        // make the swap
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of ETH
            path,
            receiver,
            block.timestamp
        );
    }

    function addLiquidity(uint256 tokenAmount, uint256 ethAmount) internal lockTheSwap {
        // approve token transfer to cover all possible scenarios
        _approve(address(this), address(uniswapV2Router), tokenAmount);

        // add the liquidity
        uniswapV2Router.addLiquidityETH{value : ethAmount}(
            address(this),
            tokenAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            liquidityWallet,
            block.timestamp
        );
    }

    function _transfer(address from, address to, uint256 amount) internal {

        if (inSwapAndLiquify || isExcludedFromFee[from] || isExcludedFromFee[to]) {
            return _directTransfer(from, to, amount);
        }

        uint256 totalFeePercentage = liquidityFeePercentage + productionFeePercentage + platformFeePercentage;
        uint256 totalFee = amount * totalFeePercentage / MULTIPLIER;
        _directTransfer(from, address(this), totalFee);
        if (from != uniswapV2Pair && balanceOf(address(this)) >= numTokensSellToAddToLiquidity) {
            uint256 liquidityFee = balanceOf(address(this)) * liquidityFeePercentage / totalFeePercentage;
            uint256 productionFee = balanceOf(address(this)) * productionFeePercentage / totalFeePercentage;
            uint256 platformFee = balanceOf(address(this)) - (liquidityFee + productionFee);

            uint256 liquidityOUATOnet = liquidityFee / 2;
            swapTokensForEth(liquidityFee - liquidityOUATOnet, address(this));
            addLiquidity(liquidityOUATOnet, address(this).balance);

            swapTokensForEth(productionFee, productionFeeWallet);
            swapTokensForEth(platformFee, platformFeeWallet);

        }
        amount = amount - totalFee;
        _directTransfer(from, to, amount);
    }

    /**
    * @dev adds or removes address from isExcludedFromFee mapping.
    */
    function updateExcludeFromFeeStatus(address account, bool exclude) public onlyRole(ADMIN_ROLE) {
        isExcludedFromFee[account] = exclude;
    }

    /**
    * @dev Returns the name of the token.
    */
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5.05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the value {ERC20} uses, unless this function is
     * overridden;
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() public view virtual override returns (uint8) {
        return 18;
    }

    /**
    * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address to, uint256 amount) public virtual override returns (bool) {
        address owner = _msgSender();
        _transfer(owner, to, amount);
        return true;
    }

    /**
     * @dev See {IERC20-allowance}.
     */
    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     * @dev See {IERC20-approve}.
     *
     * NOTE: If `amount` is the maximum `uint256`, the allowance is not updated on
     * `transferFrom`. This is semantically equivalent to an infinite approval.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, amount);
        return true;
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {ERC20}.
     *
     * NOTE: Does not update the allowance if the current allowance
     * is the maximum `uint256`.
     *
     * Requirements:
     *
     * - `from` and `to` cannot be the zero address.
     * - `from` must have a balance of at least `amount`.
     * - the caller must have allowance for ``from``'s tokens of at least
     * `amount`.
     */
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public virtual override returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
        return true;
    }

    /**
     * @dev Atomically increases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, _allowances[owner][spender] + addedValue);
        return true;
    }

    /**
     * @dev Atomically decreases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `spender` must have allowance for the caller of at least
     * `subtractedValue`.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        address owner = _msgSender();
        uint256 currentAllowance = _allowances[owner][spender];
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
    unchecked {
        _approve(owner, spender, currentAllowance - subtractedValue);
    }

        return true;
    }

    /**
     * @dev Moves `amount` of tokens from `sender` to `recipient`.
     *
     * This internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `from` must have a balance of at least `amount`.
     */
    function _directTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        uint256 fromBalance = _balances[from];
        require(fromBalance >= amount, "ERC20: transfer amount exceeds balance");
    unchecked {
        _balances[from] = fromBalance - amount;
    }
        _balances[to] += amount;

        emit Transfer(from, to, amount);
    }

    /** @dev Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply.
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     */
    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");
        _totalSupply += amount;
        _balances[account] += amount;
        emit Transfer(address(0), account, amount);
    }


    /**
     * @dev Sets `amount` as the allowance of `spender` over the `owner` s tokens.
     *
     * This internal function is equivalent to `approve`, and can be used to
     * e.g. set automatic allowances for certain subsystems, etc.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `owner` cannot be the zero address.
     * - `spender` cannot be the zero address.
     */
    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    /**
     * @dev Spend `amount` form the allowance of `owner` toward `spender`.
     *
     * Does not update the allowance amount in case of infinite allowance.
     * Revert if not enough allowance is available.
     *
     * Might emit an {Approval} event.
     */
    function _spendAllowance(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "ERC20: insufficient allowance");
        unchecked {
            _approve(owner, spender, currentAllowance - amount);
        }
        }
    }

    //to receive ETH from uniswapV2Router when swapping
    receive() external payable {}


    modifier lockTheSwap {
        inSwapAndLiquify = true;
        _;
        inSwapAndLiquify = false;
    }
}
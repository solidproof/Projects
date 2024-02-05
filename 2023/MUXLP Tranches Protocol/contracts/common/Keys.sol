// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

bytes32 constant WETH_TOKEN = keccak256("WETH_TOKEN");
bytes32 constant SMLP_TOKEN = keccak256("SMLP_TOKEN");
bytes32 constant MUX_TOKEN = keccak256("MUX_TOKEN");
bytes32 constant MCB_TOKEN = keccak256("MCB_TOKEN");
bytes32 constant MLP_TOKEN = keccak256("MLP_TOKEN");

// ======================================== JuniorVault ========================================
bytes32 constant REWARD_CONTROLLER = keccak256("REWARD_CONTROLLER");
bytes32 constant MUX_REWARD_ROUTER = keccak256("MUX_REWARD_ROUTER");
bytes32 constant MUX_LIQUIDITY_POOL = keccak256("MUX_LIQUIDITY_POOL");

// ======================================== SeniorVault ========================================
bytes32 constant LOCK_TYPE = keccak256("LOCK_TYPE");
bytes32 constant LOCK_PERIOD = keccak256("LOCK_PERIOD");
bytes32 constant LOCK_PENALTY_RATE = keccak256("LOCK_PENALTY_RATE");
bytes32 constant LOCK_PENALTY_RECIPIENT = keccak256("LOCK_PENALTY_RECIPIENT");
bytes32 constant MAX_BORROWS = keccak256("MAX_BORROWS");

// ======================================== Router ========================================
bytes32 constant TARGET_LEVERAGE = keccak256("TARGET_LEVERAGE");
bytes32 constant REBALANCE_THRESHOLD = keccak256("REBALANCE_THRESHOLD");
// bytes32 constant MUX_LIQUIDITY_POOL = keccak256("MUX_LIQUIDITY_POOL");
bytes32 constant LIQUIDATION_LEVERAGE = keccak256("LIQUIDATION_LEVERAGE"); // 10%
bytes32 constant MUX_ORDER_BOOK = keccak256("MUX_ORDER_BOOK");

// ======================================== ROLES ========================================
bytes32 constant DEFAULT_ADMIN = 0;
bytes32 constant HANDLER_ROLE = keccak256("HANDLER_ROLE");
bytes32 constant KEEPER_ROLE = keccak256("KEEPER_ROLE");
bytes32 constant CONFIG_ROLE = keccak256("CONFIG_ROLE");

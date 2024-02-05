// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/ERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/extensions/ERC20Burnable.sol";

contract DuckieToken is ERC20, Ownable, ERC20Burnable{

    constructor() ERC20("Duckie Multi Metaverse", "MMETA"){

        //developer team & marketing
        _mint(msg.sender, 30000000 * (10 ** 18));

        //advisor
        _mint(0x06cD1BA9a83415485a8476B405803D450Df41167, 6000000 * (10 ** decimals()));
        _mint(0x71d1f0a05F82c0EBd02b8704E3d15454517a6B3A, 1000000 * (10 ** decimals()));

        //Ecosystem/ Incentives/ Staking
        _mint(0x914e3CB8e6F84858806B409B176E686Cf061BA99, 34500000 * (10 ** decimals()));

        //Liquidity Pool Reward
        _mint(0x85b0804CEf176FbE954556e7aE6af813227A23E9, 5500000 * (10 ** decimals()));

        //Reserves
        _mint(0xDd1d5edFF4dD47993F4f2D847104c901121b4e9c, 8000000 * (10 ** decimals()));

        //Seed
        _mint(0x9E1cbCC8a45d0a05C69D717A43Aaaeb774A74988, 1000000 * (10 ** decimals()));
        _mint(0xE48b1cDE4Fa5c055A3AE4D2A2576197955266989, 1000000 * (10 ** decimals()));
        _mint(0x9904D8D3c56E7F75b291D1F809372edBfB0A9898, 1000000 * (10 ** decimals()));

        //Private sale
        _mint(0xcc034fd06192cfeb5b34359adf7f9f8c6f748667, 1000000 * (10 ** decimals()));
        _mint(0xb2fb1117e26F430D519FDc785e04988B1f399b45, 1000000 * (10 ** decimals()));
        _mint(0xe1160A55DFC16A2CB2B6d8563835336Dbdda2278, 1000000 * (10 ** decimals()));
        _mint(0x8B24d99be99a3239dCcA9f624fD62Db4776dcC90, 1000000 * (10 ** decimals()));
        _mint(0xC15934e8Eb6E6CA954e6dB73FF5549AeC8f41356, 1000000 * (10 ** decimals()));
        _mint(0x7efC84e61eC2C0d958EC3796590D3dF2860Bb734, 500000 * (10 ** decimals()));
        _mint(0xB41ccD2f19c49d8b57C109C2c0401b3C34e4CA90, 500000 * (10 ** decimals()));
        _mint(0x62e254842A56aF8Ba09cbD8E2cDEadA067144923, 500000 * (10 ** decimals()));
        _mint(0xf7Ef4A3ab05d61317D2B37006c54229c8dEb6B87, 500000 * (10 ** decimals()));
        _mint(0x8F4BEf79e793068f9e07CF4CE536e06549a54548, 500000 * (10 ** decimals()));
        _mint(0x4b4EA93354c2ea0E51E4566cf2900d7746E21eB2, 500000 * (10 ** decimals()));
        _mint(0x0cF603c60A2C058857210cBC539F19e48779B7Fe, 500000 * (10 ** decimals()));
        _mint(0x0aCdaA6163523da27bdf238B5dCBb3Fb98B34b47, 500000 * (10 ** decimals()));

        //public sale
        _mint(0x66D93ff9fc2C34Cd4E02858380FA3ad7E9613D89, 50000 * (10 ** decimals()));
        _mint(0x0E4CF6937B009FfA84C364398B0809DCc88e4178, 50000 * (10 ** decimals()));
        _mint(0x05850F758F8469f9038493b85bF879AEE186Fd56, 50000 * (10 ** decimals()));
        _mint(0xe2a84Bc3C3C83f8398d8Eaa0D8e26705F468B187, 50000 * (10 ** decimals()));

        //KOL
        _mint(0x0054Bb7f1C122a95C97297146867D03ca484cB65, 10000 * (10 ** decimals()));
        _mint(0xe1b22A9E3b3cd5F87a3F034311d330d731E73b36, 10000 * (10 ** decimals()));
        // _mint(0x882Ca031201f685F5abE8968c906042f9977DC6h, 10000 * (10 ** decimals()));
        // _mint(0x61e1afA97D06b4d5f31E33Fb303cba637FecBFg5, 10000 * (10 ** decimals()));
        _mint(0x7B4984Ba6D9f4C2631254F6CE44F06A7957FA08e, 10000 * (10 ** decimals()));
        _mint(0x35E7d3F031f23BA58259e86497f68Ba3f3e00E93, 10000 * (10 ** decimals()));
        // _mint(0x24b72bA4078A5c684a82bb52481fbC7a8EAed1tH, 10000 * (10 ** decimals()));
        _mint(0x839Fa1CDc102A3dD1a565a17bfd47c5ffF15D786, 10000 * (10 ** decimals()));
        _mint(0xED86E183dCdeB94B39475b6c0B8EfA71e07e6e93, 10000 * (10 ** decimals()));
        _mint(0xAd0f43F13C7d41933B3cE092b4CE6177c5519e88, 10000 * (10 ** decimals()));

        _mint(0x767ea4EC3E0D65415f5661c1D7c52b2Af1b71c43, 10000 * (10 ** decimals()));
        _mint(0x1c4f0040c0DcEfB62aB79cDECB56dce6263d2779, 10000 * (10 ** decimals()));
        // _mint(0xEEC5d9f955D047a4dF8b753A2991E1A1F1aB71G2, 10000 * (10 ** decimals()));
        _mint(0xC5848105DfaD3D1842E892C287e1c91065F49962, 10000 * (10 ** decimals()));
        _mint(0xd6fF74F36F5b1dD2d9762aD84003E2cD2287d38e, 10000 * (10 ** decimals()));
        _mint(0x668f1D8C846Bf35181f9Ebf707653368E40fe59f, 10000 * (10 ** decimals()));
        _mint(0x45666E3546606Cae2F0FACf4eC7c9a0537F25C96, 10000 * (10 ** decimals()));
        _mint(0x80A27fCb3716227e0EDf3a0FA6082d4418ad1753, 10000 * (10 ** decimals()));
        _mint(0xd79968Bda9d4FA656320FFCF7829b843Bb505307, 10000 * (10 ** decimals()));
        _mint(0x88e254842A56aF8Ba09cbD8E2cDEadA067176602, 10000 * (10 ** decimals()));

    }

}
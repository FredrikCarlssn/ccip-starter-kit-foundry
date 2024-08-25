//SPDDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {MockCCIPRouter} from "@chainlink/contracts-ccip/src/v0.8/ccip/test/mocks/MockRouter.sol";
import {Test, console, Vm} from "forge-std/Test.sol";
import {Receiver} from "../src/Receiver.sol";
import {Sender} from "../src/Sender.sol";
import {BurnMintERC677} from "@chainlink/contracts-ccip/src/v0.8/shared/token/ERC677/BurnMintERC677.sol";
import {TransferUSDC} from "../src/TransferUSDC.sol";
import {IRouterClient, CCIPLocalSimulator, WETH9, LinkToken, BurnMintERC677Helper} from "@chainlink/local/src/ccip/CCIPLocalSimulator.sol";
import "@openzeppelin/contracts/mocks/ERC20Mock.sol";

contract GasTest is Test {
    CCIPLocalSimulator public ccipLocalSimulator;
    Receiver public receiver;
    MockCCIPRouter public mockRouter;
    TransferUSDC public transferUSDC;
    TransferUSDC public transferUSDC1;
    address mockAddress = 0xc9c81Af14eC5d7a4Ca19fdC9897054e2d033bf05;
    uint64 public destinationChainId = 16015286601757825753;
    ERC20Mock public usdc;

    function setUp() public {
        // Mock router and LINK token contracts are deployed to simulate the network environment.
        mockRouter = new MockCCIPRouter();
        receiver = new Receiver(address(mockRouter));
        ccipLocalSimulator = new CCIPLocalSimulator();
        (
            uint64 chainSelector,
            IRouterClient sourceRouter,
            IRouterClient destinationRouter,
            WETH9 wrappedNative,
            LinkToken linkToken,
            BurnMintERC677Helper ccipBnM,
            BurnMintERC677Helper ccipLnM
        ) = ccipLocalSimulator.configuration();

        usdc = new ERC20Mock();
        receiver.allowlistSourceChain(chainSelector, true);
        usdc.mint(address(this), 100000000000000);
        transferUSDC = new TransferUSDC(
            address(mockRouter),
            address(linkToken),
            address(usdc)
        );
        receiver.allowlistSender(address(transferUSDC), true);
        transferUSDC1 = new TransferUSDC(
            address(mockRouter),
            address(linkToken),
            address(usdc)
        );
        usdc.mint(address(transferUSDC), 100000000000000);
        usdc.approve(address(transferUSDC), 100000000000000);
        ccipLocalSimulator.requestLinkFromFaucet(
            address(transferUSDC),
            10000000000000
        );
        ccipLocalSimulator.requestLinkFromFaucet(address(this), 10000000000000);

        transferUSDC.allowlistDestinationChain(destinationChainId, true);
    }

    function testEstimateGas() public {
        console.log("Running gas test");

        vm.recordLogs();

        transferUSDC.transferUsdc(destinationChainId, address(receiver), 100); // 4810 gas

        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 msgExecutedSignature = keccak256(
            "MsgExecuted(bool,bytes,uint256)"
        );
        console.log("Logs length: ", logs.length);

        for (uint i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == msgExecutedSignature) {
                (bool success, bytes memory retData, uint256 gasUsed) = abi
                    .decode(logs[i].data, (bool, bytes, uint256));
                console.log("MsgExecuted Event Found:");
                console.log("Success: ", success);
                console.log("Return Data: ", string(retData));
                console.log("Gas used: ", gasUsed);
            }
        }
    }
}

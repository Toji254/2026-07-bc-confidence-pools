// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Script, console2} from "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {ConfidencePool} from "src/ConfidencePool.sol";
import {ConfidencePoolFactory} from "src/ConfidencePoolFactory.sol";
import {MockConfidencePoolModerator} from "src/mocks/MockConfidencePoolModerator.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";
import {MockSafeHarborRegistry} from "test/mocks/MockSafeHarborRegistry.sol";
import {MockAgreement} from "test/mocks/MockAgreement.sol";

/// @notice Disposable Anvil environment for LowkeyCast investigation.
/// @dev Local lab only. This deploys test doubles and is never intended for a real network.
contract LocalAudit is Script {
    uint256 internal constant ONE = 1e18;
    address internal constant SCOPE_ACCOUNT = address(0xC0FFEE);

    function run() external returns (
        address factoryProxy,
        address registry,
        address token,
        address agreement,
        address pool
    ) {
        vm.startBroadcast();

        address deployer = msg.sender;

        MockERC20 stakeToken = new MockERC20();
        MockSafeHarborRegistry safeHarborRegistry = new MockSafeHarborRegistry();
        MockAgreement agreementContract = new MockAgreement(deployer);
        MockConfidencePoolModerator moderator = new MockConfidencePoolModerator();
        ConfidencePool implementation = new ConfidencePool();
        ConfidencePoolFactory factoryImplementation = new ConfidencePoolFactory();

        agreementContract.setContractInScope(SCOPE_ACCOUNT, true);
        safeHarborRegistry.setAgreementValid(address(agreementContract), true);

        bytes memory initData = abi.encodeCall(
            ConfidencePoolFactory.initialize,
            (
                address(safeHarborRegistry),
                address(implementation),
                address(moderator)
            )
        );

        factoryProxy = address(
            new ERC1967Proxy(address(factoryImplementation), initData)
        );

        ConfidencePoolFactory factory = ConfidencePoolFactory(factoryProxy);
        factory.setStakeTokenAllowed(address(stakeToken), true);

        pool = factory.createPool(
            address(agreementContract),
            address(stakeToken),
            block.timestamp + 31 days,
            ONE,
            deployer,
            _scope()
        );

        vm.stopBroadcast();

        console2.log("LOWKEY_TARGET", factoryProxy);
        console2.log("LOWKEY_REGISTRY", address(safeHarborRegistry));
        console2.log("LOWKEY_TOKEN", address(stakeToken));
        console2.log("LOWKEY_AGREEMENT", address(agreementContract));
        console2.log("LOWKEY_POOL", pool);
        console2.log("LOWKEY_ACTOR", deployer);
    }

    function _scope() internal pure returns (address[] memory accounts) {
        accounts = new address[](1);
        accounts[0] = SCOPE_ACCOUNT;
    }
}

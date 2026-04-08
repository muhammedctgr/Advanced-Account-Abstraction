// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.28;

/* solhint-disable avoid-low-level-calls */
/* solhint-disable gas-calldata-parameters */
/* solhint-disable no-inline-assembly */

import "../interfaces/ISenderCreator.sol";
import "../interfaces/IEntryPoint.sol";
import "../utils/Exec.sol";

/**
 * Helper contract for EntryPoint, to call userOp.initCode from a "neutral" address,
 * which is explicitly not the entryPoint itself.
 */
contract SenderCreator is ISenderCreator {
    error NotFromEntryPoint(address msgSender, address entity, address entryPoint);

    address public immutable entryPoint;

    constructor(){
        entryPoint = msg.sender;
    }

    uint256 private constant REVERT_REASON_MAX_LEN = 2048;

    /**
     * Call the "initCode" factory to create and return the sender account address.
     * @param initCode - The initCode value from a UserOp. contains 20 bytes of factory address,
     *                   followed by calldata.
     * @return sender  - The returned address of the created account, or zero address on failure.
     */
    function createSender(
        bytes calldata initCode
    ) external returns (address sender) {
        require(msg.sender == entryPoint, NotFromEntryPoint(msg.sender, address(this), entryPoint));
        address factory = address(bytes20(initCode[0 : 20]));

        bytes memory initCallData = initCode[20 :];
        bool success;
        assembly ("memory-safe") {
            success := call(
                gas(),
                factory,
                0,
                add(initCallData, 0x20),
                mload(initCallData),
                0,
                32
            )
            if success {
                sender := mload(0)
            }
        }
    }

    /// @inheritdoc ISenderCreator
    function initEip7702Sender(
        address sender,
        bytes memory initCallData
    ) external {
        require(msg.sender == entryPoint, NotFromEntryPoint(msg.sender, address(this), entryPoint));
        bool success;
        assembly ("memory-safe") {
            success := call(
                gas(),
                sender,
                0,
                add(initCallData, 0x20),
                mload(initCallData),
                0,
                0
            )
        }
        if (!success) {
            bytes memory result = Exec.getReturnData(REVERT_REASON_MAX_LEN);
            revert IEntryPoint.FailedOpWithRevert(0, "AA13 EIP7702 sender init failed", result);
        }
    }

     /**
     * function getSenderAddress and getFactoryAddress are not strictly required for the 
     * core functionality of SenderCreator, but they can be useful for paymasters and other contracts 
     * that want to interact with the initCode without actually creating the sender. 
     * They allow to extract the sender address and factory address from the initCode without executing any code, 
     * which can save gas and avoid potential reverts.
     * 
    */

    /**
     * get the sender address by calling the factory with the initCallData. This is useful for paymasters that 
     * want to check the sender before calling createSender.
     * Note that this function does not guarantee that the sender will actually be created, as it executes 
     * the factory code, which may have side effects or may not return the expected address. It is only a 
     * best effort to get the sender address from the initCode.
     */
    function getSenderAddress(bytes calldata initCode) external view returns (address sender) {
        address factory = address(bytes20(initCode[0 : 20]));
        bytes memory initCallData = initCode[20 :];
        (bool success, bytes memory result) = factory.staticcall(initCallData);
        if (success && result.length >= 32) {
            sender = abi.decode(result, (address));
        }
    }

    /**
     *  get the factory address from the initCode, without any call. This is useful for paymasters 
     *  that want to check the factory before calling getSenderAddress.
     *  Note that this function does not guarantee that the factory will actually create the sender, 
     * as it does not execute any code. It only extracts the factory address from the initCode.
     */
    function getFactoryAddress(bytes calldata initCode) external pure returns (address factory) {
        factory = address(bytes20(initCode[0 : 20]));
    }

    /**
     * 
     */
    function getInitCallData(bytes calldata initCode) external pure returns (bytes memory initCallData) {
        initCallData = initCode[20 :];
    }
    
    /**
     * 
     * @param initCode - The initCode value from a UserOp. contains 20 bytes of factory address,
     *                   followed by calldata.
     * @return sender - The returned address of the created account, or zero address on failure.
     * @return factory - The factory address extracted from the initCode. Note that this function does not 
     *                    guarantee that the sender will actually be created, as it executes
     */
    function getSenderAndFactory(bytes calldata initCode) external view returns (address sender, address factory) {
        factory = address(bytes20(initCode[0 : 20]));
        bytes memory initCallData = initCode[20 :];
        (bool success, bytes memory result) = factory.staticcall(initCallData);
        if (success && result.length >= 32) {
            sender = abi.decode(result, (address));
        }
    }

    /**
     * this function combines the previous three functions into one, to get the sender address, 
     * factory address and initCallData in one call. This can save gas for paymasters that want 
     * to check all three values before calling createSender. Note that this function does not 
     * guarantee that the sender will actually be created, as it executes the factory code, which 
     * may have side effects or may not return the expected address. It is only a best effort to 
     * get the sender address from the initCode.
     * 
     */
    function getSenderFactoryAndInitCallData(bytes calldata initCode) external view returns (address sender, address factory, bytes memory initCallData) {
        factory = address(bytes20(initCode[0 : 20]));
        initCallData = initCode[20 :];
        (bool success, bytes memory result) = factory.staticcall(initCallData);
        if (success && result.length >= 32) {
            sender = abi.decode(result, (address));
        }
    }

    /**
     * This function is similar to the previous one, but it also returns the raw result of the static 
     * call to the factory, which may contain additional information besides the sender address. 
     * This can be useful for paymasters that want to check the result of the factory call before calling 
     * createSender, or for debugging purposes. Note that this function does not guarantee that the sender 
     * will actually be created, as it executes the factory code, which may have side effects or may not 
     * return the expected address. It is only a best effort to get the sender address from the initCode. 
     */
    function getSenderFactoryAndInitCallDataAndResult(bytes calldata initCode) external view returns (address sender, address factory, bytes memory initCallData, bytes memory result) {
        factory = address(bytes20(initCode[0 : 20]));
        initCallData = initCode[20 :];
        (bool success, bytes memory callResult) = factory.staticcall(initCallData);
        if (success && callResult.length >= 32) {
            sender = abi.decode(callResult, (address));
            result = callResult;
        }
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import {Authorizable} from "./Authorizable.sol";
import {IAssetProxyRegistry} from "./interfaces/IAssetProxyRegistry.sol";
import {IAssetProxy} from "./interfaces/IAssetProxy.sol";

contract MultiAssetProxy is Authorizable, IAssetProxyRegistry {
  // Id of this proxy.
  bytes4 internal constant PROXY_ID =
    bytes4(keccak256("MultiAsset(uint256[],bytes[])"));

  // Mapping from Asset Proxy Id's to their respective Asset Proxy
  mapping(bytes4 => address) internal _assetProxies;

  /// @dev Registers an asset proxy to its asset proxy id.
  ///      Once an asset proxy is registered, it cannot be unregistered.
  /// @param assetProxy Address of new asset proxy to register.
  function registerAssetProxy(address assetProxy) external override onlyOwner {
    // Ensure that no asset proxy exists with current id.
    bytes4 assetProxyId = IAssetProxy(assetProxy).getProxyId();
    // Add asset proxy and log registration.
    _assetProxies[assetProxyId] = assetProxy;
    emit AssetProxyRegistered(assetProxyId, assetProxy);
  }

  /// @dev Gets an asset proxy.
  /// @param assetProxyId Id of the asset proxy.
  /// @return assetProxy The asset proxy address registered to assetProxyId. Returns 0x0 if no proxy is registered.
  function getAssetProxy(
    bytes4 assetProxyId
  ) external view override returns (address assetProxy) {
    return _assetProxies[assetProxyId];
  }

  // solhint-disable-next-line payable-fallback
  fallback() external onlyAuthorized {
    // NOTE: The below assembly assumes that clients do some input validation and that the input is properly encoded according to the AbiV2 specification.
    // It is technically possible for inputs with very large lengths and offsets to cause overflows. However, this would make the calldata prohibitively
    // expensive and we therefore do not check for overflows in these scenarios.
    assembly {
      // The first 4 bytes of calldata holds the function selector
      let selector := and(
        calldataload(0),
        0xffffffff00000000000000000000000000000000000000000000000000000000
      )

      // `transferFrom` will be called with the following parameters:
      // assetData Encoded byte array.
      // from Address to transfer asset from.
      // to Address to transfer asset to.
      // amount Amount of asset to transfer.
      // bytes4(keccak256("transferFrom(bytes,address,address,uint256)")) = 0xa85e59e4
      if eq(
        selector,
        0xa85e59e400000000000000000000000000000000000000000000000000000000
      ) {
        // To lookup a value in a mapping, we load from the storage location keccak256(k, p),
        // where k is the key left padded to 32 bytes and p is the storage slot
        mstore(0, caller())
        mstore(32, authorized.slot)

        // Revert if authorized[msg.sender] == false
        if iszero(sload(keccak256(0, 64))) {
          // Revert with `Error("SENDER_NOT_AUTHORIZED")`
          mstore(
            0,
            0x08c379a000000000000000000000000000000000000000000000000000000000
          )
          mstore(
            32,
            0x0000002000000000000000000000000000000000000000000000000000000000
          )
          mstore(
            64,
            0x0000001553454e4445525f4e4f545f415554484f52495a454400000000000000
          )
          mstore(96, 0)
          revert(0, 100)
        }

        // `transferFrom`.
        // The function is marked `external`, so no abi decoding is done for
        // us. Instead, we expect the `calldata` memory to contain the
        // following:
        //
        // | Area     | Offset | Length  | Contents                            |
        // |----------|--------|---------|-------------------------------------|
        // | Header   | 0      | 4       | function selector                   |
        // | Params   |        | 4 * 32  | function parameters:                |
        // |          | 4      |         |   1. offset to assetData (*)        |
        // |          | 36     |         |   2. from                           |
        // |          | 68     |         |   3. to                             |
        // |          | 100    |         |   4. amount                         |
        // | Data     |        |         | assetData:                          |
        // |          | 132    | 32      | assetData Length                    |
        // |          | 164    | **      | assetData Contents                  |
        //
        // (*): offset is computed from start of function parameters, so offset
        //      by an additional 4 bytes in the calldata.
        //
        // (**): see table below to compute length of assetData Contents
        //
        // WARNING: The ABIv2 specification allows additional padding between
        //          the Params and Data section. This will result in a larger
        //          offset to assetData.

        // Load offset to `assetData`
        let assetDataOffset := add(calldataload(4), 4)

        // Load length in bytes of `assetData`
        // let calldataload(assetDataOffset) := calldataload(assetDataOffset)

        // Asset data itself is encoded as follows:
        //
        // | Area     | Offset      | Length  | Contents                            |
        // |----------|-------------|---------|-------------------------------------|
        // | Header   | 0           | 4       | assetProxyId                        |
        // | Params   |             | 2 * 32  | function parameters:                |
        // |          | 4           |         |   1. offset to amounts (*)          |
        // |          | 36          |         |   2. offset to nestedAssetData (*)  |
        // | Data     |             |         | amounts:                            |
        // |          | 68          | 32      | amounts Length                      |
        // |          | 100         | a       | amounts Contents                    |
        // |          |             |         | nestedAssetData:                    |
        // |          | 100 + a     | 32      | nestedAssetData Length              |
        // |          | 132 + a     | b       | nestedAssetData Contents (offsets)  |
        // |          | 132 + a + b |         | nestedAssetData[0, ..., len]        |

        // Assert that the length of asset data:
        // 1. Must be at least 68 bytes (see table above)
        // 2. Must be a multiple of 32 (excluding the 4-byte selector)
        if or(
          lt(calldataload(assetDataOffset), 68),
          mod(sub(calldataload(assetDataOffset), 4), 32)
        ) {
          // Revert with `Error("INVALID_ASSET_DATA_LENGTH")`
          mstore(
            0,
            0x08c379a000000000000000000000000000000000000000000000000000000000
          )
          mstore(
            32,
            0x0000002000000000000000000000000000000000000000000000000000000000
          )
          mstore(
            64,
            0x00000019494e56414c49445f41535345545f444154415f4c454e475448000000
          )
          mstore(96, 0)
          revert(0, 100)
        }

        // End of asset data in calldata
        // assetDataOffset
        // + 32 (assetData len)
        // let assetDataEnd := add(assetDataOffset, add(calldataload(assetDataOffset), 32))
        if gt(
          add(assetDataOffset, add(calldataload(assetDataOffset), 32)),
          calldatasize()
        ) {
          // Revert with `Error("INVALID_ASSET_DATA_END")`
          mstore(
            0,
            0x08c379a000000000000000000000000000000000000000000000000000000000
          )
          mstore(
            32,
            0x0000002000000000000000000000000000000000000000000000000000000000
          )
          mstore(
            64,
            0x00000016494e56414c49445f41535345545f444154415f454e44000000000000
          )
          mstore(96, 0)
          revert(0, 100)
        }

        // In order to find the offset to `amounts`, we must add:
        // assetDataOffset
        // + 32 (assetData len)
        // + 4 (assetProxyId)
        let amountsOffset := calldataload(add(assetDataOffset, 36))

        // In order to find the offset to `nestedAssetData`, we must add:
        // assetDataOffset
        // + 32 (assetData len)
        // + 4 (assetProxyId)
        // + 32 (amounts offset)
        let nestedAssetDataOffset := calldataload(add(assetDataOffset, 68))

        // In order to find the start of the `amounts` contents, we must add:
        // assetDataOffset
        // + 32 (assetData len)
        // + 4 (assetProxyId)
        // + amountsOffset
        // + 32 (amounts len)
        let amountsContentsStart := add(assetDataOffset, add(amountsOffset, 68))

        // Load number of elements in `amounts`
        let amountsLen := calldataload(sub(amountsContentsStart, 32))

        // In order to find the start of the `nestedAssetData` contents, we must add:
        // assetDataOffset
        // + 32 (assetData len)
        // + 4 (assetProxyId)
        // + nestedAssetDataOffset
        // + 32 (nestedAssetData len)
        let nestedAssetDataContentsStart := add(
          assetDataOffset,
          add(nestedAssetDataOffset, 68)
        )

        // Load number of elements in `nestedAssetData`
        let nestedAssetDataLen := calldataload(
          sub(nestedAssetDataContentsStart, 32)
        )

        // Revert if number of elements in `amounts` differs from number of elements in `nestedAssetData`
        if sub(amountsLen, nestedAssetDataLen) {
          // Revert with `Error("LENGTH_MISMATCH")`
          mstore(
            0,
            0x08c379a000000000000000000000000000000000000000000000000000000000
          )
          mstore(
            32,
            0x0000002000000000000000000000000000000000000000000000000000000000
          )
          mstore(
            64,
            0x0000000f4c454e4754485f4d49534d4154434800000000000000000000000000
          )
          mstore(96, 0)
          revert(0, 100)
        }

        // Copy `transferFrom` selector, offset to `assetData`, `from`, and `to` from calldata to memory
        calldatacopy(
          0, // memory can safely be overwritten from beginning
          0, // start of calldata
          100 // length of selector (4) and 3 params (32 * 3)
        )

        // Overwrite existing offset to `assetData` with our own
        mstore(4, 128)

        // Load `amount`
        let amount := calldataload(100)

        // Calculate number of bytes in `amounts` contents
        let amountsByteLen := mul(amountsLen, 32)

        // Initialize `assetProxyId` and `assetProxy` to 0
        let assetProxyId := 0
        let assetProxy := 0

        // Loop through `amounts` and `nestedAssetData`, calling `transferFrom` for each respective element
        for {
          let i := 0
        } lt(i, amountsByteLen) {
          i := add(i, 32)
        } {
          // Calculate the total amount
          let amountsElement := calldataload(add(amountsContentsStart, i))
          let totalAmount := mul(amountsElement, amount)

          // Revert if `amount` != 0 and multiplication resulted in an overflow
          if iszero(
            or(iszero(amount), eq(div(totalAmount, amount), amountsElement))
          ) {
            // Revert with `Error("UINT256_OVERFLOW")`
            mstore(
              0,
              0x08c379a000000000000000000000000000000000000000000000000000000000
            )
            mstore(
              32,
              0x0000002000000000000000000000000000000000000000000000000000000000
            )
            mstore(
              64,
              0x0000001055494e543235365f4f564552464c4f57000000000000000000000000
            )
            mstore(96, 0)
            revert(0, 100)
          }

          // Write `totalAmount` to memory
          mstore(100, totalAmount)

          // Load offset to `nestedAssetData[i]`
          let nestedAssetDataElementOffset := calldataload(
            add(nestedAssetDataContentsStart, i)
          )

          // In order to find the start of the `nestedAssetData[i]` contents, we must add:
          // assetDataOffset
          // + 32 (assetData len)
          // + 4 (assetProxyId)
          // + nestedAssetDataOffset
          // + 32 (nestedAssetData len)
          // + nestedAssetDataElementOffset
          // + 32 (nestedAssetDataElement len)
          let nestedAssetDataElementContentsStart := add(
            assetDataOffset,
            add(nestedAssetDataOffset, add(nestedAssetDataElementOffset, 100))
          )

          // Load length of `nestedAssetData[i]`
          let nestedAssetDataElementLenStart := sub(
            nestedAssetDataElementContentsStart,
            32
          )
          let nestedAssetDataElementLen := calldataload(
            nestedAssetDataElementLenStart
          )

          // Revert if the `nestedAssetData` does not contain a 4 byte `assetProxyId`
          if lt(nestedAssetDataElementLen, 4) {
            // Revert with `Error("LENGTH_GREATER_THAN_3_REQUIRED")`
            mstore(
              0,
              0x08c379a000000000000000000000000000000000000000000000000000000000
            )
            mstore(
              32,
              0x0000002000000000000000000000000000000000000000000000000000000000
            )
            mstore(
              64,
              0x0000001e4c454e4754485f475245415445525f5448414e5f335f524551554952
            )
            mstore(
              96,
              0x4544000000000000000000000000000000000000000000000000000000000000
            )
            revert(0, 100)
          }

          // Load AssetProxy id
          let currentAssetProxyId := and(
            calldataload(nestedAssetDataElementContentsStart),
            0xffffffff00000000000000000000000000000000000000000000000000000000
          )

          // Only load `assetProxy` if `currentAssetProxyId` does not equal `assetProxyId`
          // We do not need to check if `currentAssetProxyId` is 0 since `assetProxy` is also initialized to 0
          if sub(currentAssetProxyId, assetProxyId) {
            // Update `assetProxyId`
            assetProxyId := currentAssetProxyId
            // To lookup a value in a mapping, we load from the storage location keccak256(k, p),
            // where k is the key left padded to 32 bytes and p is the storage slot
            mstore(132, assetProxyId)
            mstore(164, _assetProxies.slot)
            assetProxy := sload(keccak256(132, 64))
          }

          // Revert if AssetProxy with given id does not exist
          if iszero(assetProxy) {
            // Revert with `Error("ASSET_PROXY_DOES_NOT_EXIST")`
            mstore(
              0,
              0x08c379a000000000000000000000000000000000000000000000000000000000
            )
            mstore(
              32,
              0x0000002000000000000000000000000000000000000000000000000000000000
            )
            mstore(
              64,
              0x0000001a41535345545f50524f58595f444f45535f4e4f545f45584953540000
            )
            mstore(96, 0)
            revert(0, 100)
          }

          // Copy `nestedAssetData[i]` from calldata to memory
          calldatacopy(
            132, // memory slot after `amounts[i]`
            nestedAssetDataElementLenStart, // location of `nestedAssetData[i]` in calldata
            add(nestedAssetDataElementLen, 32) // `nestedAssetData[i].length` plus 32 byte length
          )

          // call `assetProxy.transferFrom`
          let success := call(
            gas(), // forward all gas
            assetProxy, // call address of asset proxy
            0, // don't send any ETH
            0, // pointer to start of input
            add(164, nestedAssetDataElementLen), // length of input
            0, // write output over memory that won't be reused
            0 // don't copy output to memory
          )

          // Revert with reason given by AssetProxy if `transferFrom` call failed
          if iszero(success) {
            returndatacopy(
              0, // copy to memory at 0
              0, // copy from return data at 0
              returndatasize() // copy all return data
            )
            revert(0, returndatasize())
          }
        }

        // Return if no `transferFrom` calls reverted
        return(0, 0)
      }

      // Revert if undefined function is called
      revert(0, 0)
    }
  }

  /// @dev Gets the proxy id associated with the proxy address.
  /// @return Proxy id.
  function getProxyId() external pure returns (bytes4) {
    return PROXY_ID;
  }
}

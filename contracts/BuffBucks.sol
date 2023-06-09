// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {AutomationCompatibleInterface} from "@chainlink/contracts/src/v0.8/AutomationCompatible.sol";
import {Functions, FunctionsClient} from "./dev/functions/FunctionsClient.sol";
import {ConfirmedOwner} from "@chainlink/contracts/src/v0.8/ConfirmedOwner.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./IBuffCoupons.sol";

/**
 * @title BurnToEarn
 * @author Gabriel Antony Xaviour
 * @dev A contract for managing BurnToEarn tokens.
 */
contract BurnToEarn is ERC20, ERC20Burnable, FunctionsClient, ConfirmedOwner {
  using Functions for Functions.Request;

  string private functionSourceCode;
  string private registerAccountSourceCode;
  mapping(bytes32 => address) public mintRequestRegistry;
  mapping(bytes32 => address) public registerRequestRegistry;
  mapping(address => string) private userEmail;
  mapping(address => uint256) private lastClaimed;

  bytes32 public latestRequestId;
  bytes public latestResponse;
  bytes public latestError;

  event TokensMinted(bytes32 indexed requestId, address claimer, uint256 tokensMinted, uint256 timestamp);
  event ErrorOccured(bytes32 indexed requestId, address claimer, bytes error);
  event AccountRegistered(bytes32 indexed requestId, address claimer, string emailAddress, uint256 timestamp);
  event CouponsClaimed(address claimer, uint256 tokenId, uint256 tokenPrice, uint256 timestamp);

  /**
   * @dev Initializes the BurnToEarn contract.
   * @param oracle The address of the Functions oracle.
   * @param _functionSourceCode The source code for executing functions.
   * @param _registerAccountSourceCode The source code for registering an account.
   */
  constructor(
    address oracle,
    string memory _functionSourceCode,
    string memory _registerAccountSourceCode
  ) FunctionsClient(oracle) ConfirmedOwner(msg.sender) ERC20("Buff Bucks", "BB") {
    functionSourceCode = _functionSourceCode;
    registerAccountSourceCode = _registerAccountSourceCode;
  }

  /**
   * @notice Registers an account with the specified arguments.
   * @param args The arguments for registering the account.
   * @param secrets The encrypted secrets payload.
   * @param subscriptionId Functions billing subscription ID.
   * @param gasLimit Maximum amount of gas used to call the client contract's `handleOracleFulfillment` function.
   */
  function registerAccount(
    string[] calldata args,
    bytes calldata secrets,
    uint64 subscriptionId,
    uint32 gasLimit
  ) public {
    require(bytes(userEmail[msg.sender]).length == 0, "Device already registered");
    bytes32 requestId = _executeRequest(registerAccountSourceCode, secrets, args, subscriptionId, gasLimit);
    registerRequestRegistry[requestId] = msg.sender;
  }

  /**
   * @notice Mints BurnToEarn tokens to the caller's account.
   * @param secrets The encrypted secrets payload.
   * @param subscriptionId Functions billing subscription ID.
   * @param gasLimit Maximum amount of gas used to call the client contract's `handleOracleFulfillment` function.
   */
  function mintTokens(
    bytes memory secrets,
    uint64 subscriptionId,
    uint32 gasLimit
  ) public {
    string[] memory args = new string[](2);
    args[0] = userEmail[msg.sender];
    args[1] = Strings.toString(lastClaimed[msg.sender]);
    bytes32 requestId = _executeRequest(functionSourceCode, secrets, args, subscriptionId, gasLimit);
    mintRequestRegistry[requestId] = msg.sender;
  }

  /**
   * @notice Claims coupons from the specified `couponsContract`.
   * @param couponsContract The address of the BuffCoupons contract.
   * @param tokenId The ID of the token to claim.
   */
  function claimCoupons(IBuffCoupons couponsContract, uint256 tokenId) public {
    require(couponsContract.isAffordable(tokenId, balanceOf(msg.sender)), "Cannot afford coupon");
    uint256 tokenPrice = couponsContract.getTokenPrice(tokenId);
    _burn(msg.sender, tokenPrice);
    couponsContract.mint(msg.sender, tokenId, "");
    emit CouponsClaimed(msg.sender, tokenId, tokenPrice, block.timestamp);
  }

  /**
   * @notice Executes a request by invoking the Functions oracle.
   * @param source The source code for the request.
   * @param secrets The encrypted secrets payload.
   * @param args The arguments accessible from within the source code.
   * @param subscriptionId Functions billing subscription ID.
   * @param gasLimit Maximum amount of gas used to call the client contract's `handleOracleFulfillment` function.
   * @return The Functions request ID.
   */
  function _executeRequest(
    string memory source,
    bytes memory secrets,
    string[] memory args,
    uint64 subscriptionId,
    uint32 gasLimit
  ) internal returns (bytes32) {
    Functions.Request memory req;
    req.initializeRequest(Functions.Location.Inline, Functions.CodeLanguage.JavaScript, source);
    if (secrets.length > 0) {
      req.addRemoteSecrets(secrets);
    }
    if (args.length > 0) req.addArgs(args);

    bytes32 assignedReqID = sendRequest(req, subscriptionId, gasLimit);
    return assignedReqID;
  }

  /**
   * @notice Callback that is invoked once the DON has resolved the request or hit an error.
   * @param requestId The request ID returned by sendRequest().
   * @param response The aggregated response from the user code.
   * @param err The aggregated error from the user code or from the execution pipeline.
   * Either response or error parameter will be set, but never both.
   */
  function fulfillRequest(
    bytes32 requestId,
    bytes memory response,
    bytes memory err
  ) internal override {
    if (mintRequestRegistry[requestId] != address(0)) {
      if (response.length > 0) {
        uint256 amount = abi.decode(response, (uint256));
        _mint(mintRequestRegistry[requestId], amount);
        lastClaimed[mintRequestRegistry[requestId]] = block.timestamp;
        emit TokensMinted(requestId, mintRequestRegistry[requestId], amount, block.timestamp);
      } else {
        emit ErrorOccured(requestId, mintRequestRegistry[requestId], err);
      }
    } else if (registerRequestRegistry[requestId] != address(0)) {
      if (response.length > 0) {
        string memory emailAddress = string(response);
        userEmail[registerRequestRegistry[requestId]] = emailAddress;
        emit AccountRegistered(requestId, registerRequestRegistry[requestId], emailAddress, block.timestamp);
      } else {
        emit ErrorOccured(requestId, registerRequestRegistry[requestId], err);
      }
    }
  }

  /**
   * @notice Allows updating the Functions oracle address.
   * @param oracle The new oracle address.
   */
  function updateOracleAddress(address oracle) public onlyOwner {
    setOracle(oracle);
  }

  function updateRegisterSourceCode(string memory _registerAccountSourceCode) public onlyOwner {
    registerAccountSourceCode = _registerAccountSourceCode;
  }

  function updateFunctionSourceCode(string memory _functionSourceCode) public onlyOwner {
    functionSourceCode = _functionSourceCode;
  }

  /**
   * @notice Adds a simulated request ID for testing purposes.
   * @param oracleAddress The address of the oracle.
   * @param requestId The simulated request ID.
   */
  function addSimulatedRequestId(address oracleAddress, bytes32 requestId) public onlyOwner {
    addExternalRequest(oracleAddress, requestId);
  }

  /**
   * @dev Returns the source code of the function.
   * @return The source code as a string.
   */
  function getFunctionSourceCode() public view returns (string memory) {
    return functionSourceCode;
  }

  /**
   * @dev Returns the source code of the register account function.
   * @return The source code as a string.
   */
  function getRegisterAccountSourceCode() public view returns (string memory) {
    return registerAccountSourceCode;
  }

  /**
   * @dev Returns the email associated with the given wallet address.
   * @param walletAddress The wallet address for which to retrieve the email.
   * @return The email address as a string.
   */
  function getUserEmail(address walletAddress) public view returns (string memory) {
    return userEmail[walletAddress];
  }

  /**
   * @dev Returns the last claimed timestamp for the specified wallet address.
   * @param walletAddress The wallet address for which to retrieve the last claimed timestamp.
   * @return The last claimed timestamp as a uint256 value.
   */
  function getLastClaimed(address walletAddress) public view returns (uint256) {
    return lastClaimed[walletAddress];
  }

  // Utils functions
  function bytes32ToString(bytes32 value) internal pure returns (string memory) {
    bytes memory byteArray = new bytes(32);
    for (uint256 i = 0; i < 32; i++) {
      byteArray[i] = value[i];
    }
    return string(byteArray);
  }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

/**
 * @title BuffCoupons
 * @dev A smart contract for managing Buff Coupons, which are ERC1155 tokens with URI and price.
 * Users can create, update, and mint tokens using Buff Bucks as payment.
 * Implements ERC1155 and ERC1155URIStorage from the OpenZeppelin library.
 * Only the contract owner can perform certain operations.
 * @author Gabriel Antony Xaviour
 */
contract BuffCoupons is ERC1155, ERC1155URIStorage, Ownable {
  using Counters for Counters.Counter;

  Counters.Counter private _tokenIdCounter;

  mapping(uint256 => uint256) public tokenPrice;
  address public immutable burntoearnContract;

  event TokenCreated(uint256 tokenId, string uri, uint256 timestamp);
  event TokenMinted(uint256 tokenId, address to, uint256 price, uint256 timestamp);
  event TokenPriceUpdated(uint256 tokenId, uint256 price, uint256 timestamp);
  event TokenURIUpdated(uint256 tokenId, string uri, uint256 timestamp);

  constructor(address _burntoearnContract) ERC1155("") {
    burntoearnContract = _burntoearnContract;
  }

  /**
   * @dev Creates a new token with the given URI and price.
   * Only the contract owner can call this function.
   * @param _uri The URI of the token.
   * @param price The price of the token.
   */
  function createToken(string memory _uri, uint256 price) public onlyOwner {
    uint256 _tokenId = _tokenIdCounter.current();
    _setURI(_tokenId, _uri);
    _tokenIdCounter.increment();
    tokenPrice[_tokenId] = price;
    emit TokenCreated(_tokenId, _uri, block.timestamp);
  }

  /**
   * @dev Updates the price of an existing token.
   * Only the contract owner can call this function.
   * @param tokenId The ID of the token.
   * @param price The new price of the token.
   */
  function updateTokenPrice(uint256 tokenId, uint256 price) public onlyOwner {
    require(tokenExists(tokenId), "Token does not exist");
    tokenPrice[tokenId] = price;
    emit TokenPriceUpdated(tokenId, price, block.timestamp);
  }

  /**
   * @dev Updates the URI of an existing token.
   * Only the contract owner can call this function.
   * @param tokenId The ID of the token.
   * @param newuri The new URI of the token.
   */
  function setURI(uint256 tokenId, string memory newuri) public onlyOwner {
    _setURI(tokenId, newuri);
    emit TokenURIUpdated(tokenId, newuri, block.timestamp);
  }

  /**
   * @dev Mints a token to the specified account.
   * Only the Buff Bucks contract can call this function directly.
   * @param account The account to mint the token to.
   * @param id The ID of the token.
   * @param data Additional data to pass to the receiver contract.
   */
  function mint(
    address account,
    uint256 id,
    bytes memory data
  ) public {
    require(msg.sender == burntoearnContract, "Direct mint invalid");
    _mint(account, id, 1, data);
    emit TokenMinted(id, account, tokenPrice[id], block.timestamp);
  }

  // Overrides
  function uri(uint256 tokenId) public view override(ERC1155, ERC1155URIStorage) returns (string memory) {
    return super.uri(tokenId);
  }

  // Getters
  /**
   * @dev Checks if a token with the given ID exists.
   * @param tokenId The ID of the token.
   * @return A boolean indicating whether the token exists.
   */
  function tokenExists(uint256 tokenId) public view returns (bool) {
    return tokenId < _tokenIdCounter.current();
  }

  /**
   * @dev Gets the total number of tokens created.
   * @return The total number of tokens.
   */
  function getTotalTokens() public view returns (uint256) {
    return _tokenIdCounter.current();
  }

  /**
   * @dev Checks if the specified number of tokens can be afforded for the given token ID.
   * @param tokenId The ID of the token.
   * @param tokens The number of tokens to check affordability for.
   * @return A boolean indicating whether the tokens can be afforded.
   */
  function isAffordable(uint256 tokenId, uint256 tokens) public view returns (bool) {
    require(tokenExists(tokenId), "Token does not exist");
    return tokenPrice[tokenId] <= tokens;
  }

  /**
   * @dev Gets the price of the specified token.
   * @param tokenId The ID of the token.
   * @return The price of the token.
   */
  function getTokenPrice(uint256 tokenId) public view returns (uint256) {
    require(tokenExists(tokenId), "Token does not exist");
    return tokenPrice[tokenId];
  }
}

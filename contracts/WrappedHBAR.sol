pragma solidity 0.4.24;

import "chainlink/contracts/ChainlinkClient.sol";
import "./ERC20Detailed.sol";
import "./ERC20.sol";
import "./Ownable.sol";

/**
 * @title WrappedHBAR is an example contract which requests data from
 * the Chainlink network
 * @dev This contract is designed to work on multiple networks, including
 * local test networks
 */
contract WrappedHBAR is ChainlinkClient, ERC20Detailed, ERC20, Ownable {
  uint256 public data;
  uint256 public flag;
  address public person;

  mapping (address => uint256) public balances;
  // mapping (bytes32 => bool) public claimed;
  
  event LogMintWHBAR(address account, uint amount);
  event LogBurnWHBAR(address account, uint amount);

  /**
   * @notice Deploy the contract with a specified address for the LINK
   * and Oracle contract addresses
   * @dev Sets the storage for the specified addresses
   * @param _link The address of the LINK token contract
   */
  constructor(
    address _link,
    string memory _name,
    string memory _symbol,
    uint8 _decimals
    ) public ERC20Detailed(_name, _symbol, _decimals) {
    if (_link == address(0)) {
      setPublicChainlinkToken();
    } else {
      setChainlinkToken(_link);
    }
  }

  /**
   * @notice Returns the address of the LINK token
   * @dev This is the public implementation for chainlinkTokenAddress, which is
   * an internal method of the ChainlinkClient contract
   */
  function getChainlinkToken() public view returns (address) {
    return chainlinkTokenAddress();
  }


  function requestToken(
    address _oracle,
    bytes32 _jobId,
    uint256 _payment,
    string _url,
    string _path,
    int256 _times,
    address user
  ) public returns (uint) {
    // Fetch amount from oracle
    person = user;
    createRequestTo(_oracle, _jobId, _payment, _url, _path, _times);

    flag = 2;
    // Increase balance of sender
    // require(data >= 0, "Deposit not found on hedera");
    // _mint(user, data);
    balances[user] += data;

    emit LogMintWHBAR(user, data);
    // data = 0;
    return balances[user];
  }


  function withdrawToken(uint amount) public returns (uint) {

    require(balances[msg.sender] >= amount, "Insufficient funds to burn");
    balances[msg.sender] -= amount;

    _burn(msg.sender, amount);

    emit LogBurnWHBAR(msg.sender, amount);
    return balances[msg.sender];
  }
  /**
   * @notice Creates a request to the specified Oracle contract address
   * @dev This function ignores the stored Oracle contract address and
   * will instead send the request to the address specified
   * @param _oracle The Oracle contract address to send the request to
   * @param _jobId The bytes32 JobID to be executed
   * @param _url The URL to fetch data from
   * @param _path The dot-delimited path to parse of the response
   * @param _times The number to multiply the result by
   */
  function createRequestTo(
    address _oracle,
    bytes32 _jobId,
    uint256 _payment,
    string _url,
    string _path,
    int256 _times
  )
    public
    returns (bytes32 requestId)
  {
    Chainlink.Request memory req = buildChainlinkRequest(_jobId, this, this.fulfill.selector);
    req.add("url", _url);
    req.add("path", _path);
    req.addInt("times", _times);
    requestId = sendChainlinkRequestTo(_oracle, req, _payment);
  }

  /**
   * @notice The fulfill method from requests created by this contract
   * @dev The recordChainlinkFulfillment protects this function from being called
   * by anyone other than the oracle address that the request was sent to
   * @param _requestId The ID that was generated for the request
   * @param _data The answer provided by the oracle
   */
  function fulfill(bytes32 _requestId, uint256 _data)
    public
    recordChainlinkFulfillment(_requestId) returns (uint)
  {
    data = _data;
    _mint(person, data);
  }

  /**
   * @notice Allows the owner to withdraw any LINK balance on the contract
   */
  function withdrawLink() public {
    LinkTokenInterface link = LinkTokenInterface(chainlinkTokenAddress());
    require(link.transfer(msg.sender, link.balanceOf(address(this))), "Unable to transfer");
  }

  /**
   * @notice Call this method if no response is received within 5 minutes
   * @param _requestId The ID that was generated for the request to cancel
   * @param _payment The payment specified for the request to cancel
   * @param _callbackFunctionId The bytes4 callback function ID specified for
   * the request to cancel
   * @param _expiration The expiration generated for the request to cancel
   */
  function cancelRequest(
    bytes32 _requestId,
    uint256 _payment,
    bytes4 _callbackFunctionId,
    uint256 _expiration
  )
    public
  {
    cancelChainlinkRequest(_requestId, _payment, _callbackFunctionId, _expiration);
  }
} 
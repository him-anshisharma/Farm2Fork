// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Farm2Fork
 * @dev A smart contract for tracking agricultural products from farm to consumer
 * @author Blockchain Developer
 */
contract Farm2Fork {
    // State variables
    address public owner;
    uint256 public productCounter;
    
    // Enums
    enum ProductStatus {
        Planted,
        Harvested,
        Processed,
        Packaged,
        InTransit,
        AtRetailer,
        Sold
    }
    
    enum UserRole {
        None,
        Farmer,
        Processor,
        Distributor,
        Retailer,
        Consumer
    }
    
    // Structs
    struct Product {
        uint256 id;
        string name;
        string variety;
        address farmer;
        uint256 plantedDate;
        uint256 harvestedDate;
        string farmLocation;
        ProductStatus status;
        bool isOrganic;
        uint256 batchSize;
        string certifications;
        bool exists;
    }
    
    struct SupplyChainStep {
        address actor;
        UserRole role;
        uint256 timestamp;
        string location;
        string action;
        string additionalInfo;
    }
    
    struct User {
        address userAddress;
        string name;
        UserRole role;
        string location;
        bool isVerified;
        uint256 registrationDate;
    }
    
    // Mappings
    mapping(uint256 => Product) public products;
    mapping(uint256 => SupplyChainStep[]) public supplyChainHistory;
    mapping(address => User) public users;
    mapping(address => bool) public authorizedUsers;
    mapping(UserRole => uint256) public roleCount;
    
    // Arrays
    uint256[] public productIds;
    address[] public userAddresses;
    
    // Events
    event ProductRegistered(
        uint256 indexed productId, 
        string name, 
        address indexed farmer,
        uint256 timestamp
    );
    event ProductStatusUpdated(
        uint256 indexed productId, 
        ProductStatus newStatus, 
        address indexed updatedBy,
        uint256 timestamp
    );
    event SupplyChainStepAdded(
        uint256 indexed productId, 
        address indexed actor, 
        string action,
        uint256 timestamp
    );
    event UserRegistered(
        address indexed userAddress, 
        string name, 
        UserRole role,
        uint256 timestamp
    );
    event UserVerified(address indexed userAddress, uint256 timestamp);
    
    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    
    modifier onlyAuthorizedUser() {
        require(authorizedUsers[msg.sender], "User not authorized");
        _;
    }
    
    modifier onlyRole(UserRole _role) {
        require(users[msg.sender].role == _role, "Invalid role for this action");
        _;
    }
    
    modifier productExists(uint256 _productId) {
        require(products[_productId].exists, "Product does not exist");
        _;
    }
    
    modifier onlyVerifiedUser() {
        require(users[msg.sender].isVerified, "User must be verified");
        _;
    }
    
    // Constructor
    constructor() {
        owner = msg.sender;
        productCounter = 0;
    }
    
    /**
     * @dev Core Function 1: Register a new agricultural product
     * @param _name Name of the product
     * @param _variety Variety of the product
     * @param _farmLocation Location where the product was grown
     * @param _isOrganic Whether the product is organic
     * @param _batchSize Size of the batch
     * @param _certifications Any certifications (organic, fair trade, etc.)
     */
    function registerProduct(
        string memory _name,
        string memory _variety,
        string memory _farmLocation,
        bool _isOrganic,
        uint256 _batchSize,
        string memory _certifications
    ) public onlyRole(UserRole.Farmer) onlyVerifiedUser returns (uint256) {
        require(bytes(_name).length > 0, "Product name cannot be empty");
        require(bytes(_farmLocation).length > 0, "Farm location cannot be empty");
        require(_batchSize > 0, "Batch size must be greater than 0");
        
        productCounter++;
        uint256 newProductId = productCounter;
        
        products[newProductId] = Product({
            id: newProductId,
            name: _name,
            variety: _variety,
            farmer: msg.sender,
            plantedDate: block.timestamp,
            harvestedDate: 0,
            farmLocation: _farmLocation,
            status: ProductStatus.Planted,
            isOrganic: _isOrganic,
            batchSize: _batchSize,
            certifications: _certifications,
            exists: true
        });
        
        productIds.push(newProductId);
        
        // Add initial supply chain step
        supplyChainHistory[newProductId].push(SupplyChainStep({
            actor: msg.sender,
            role: UserRole.Farmer,
            timestamp: block.timestamp,
            location: _farmLocation,
            action: "Product Planted",
            additionalInfo: string(abi.encodePacked("Batch Size: ", _batchSize))
        }));
        
        emit ProductRegistered(newProductId, _name, msg.sender, block.timestamp);
        emit SupplyChainStepAdded(newProductId, msg.sender, "Product Planted", block.timestamp);
        
        return newProductId;
    }
    
    /**
     * @dev Core Function 2: Update product status and add supply chain step
     * @param _productId ID of the product to update
     * @param _newStatus New status of the product
     * @param _location Current location of the product
     * @param _action Action being performed
     * @param _additionalInfo Additional information about the action
     */
    function updateProductStatus(
        uint256 _productId,
        ProductStatus _newStatus,
        string memory _location,
        string memory _action,
        string memory _additionalInfo
    ) public productExists(_productId) onlyAuthorizedUser onlyVerifiedUser {
        require(
            _isValidStatusTransition(products[_productId].status, _newStatus),
            "Invalid status transition"
        );
        require(bytes(_location).length > 0, "Location cannot be empty");
        require(bytes(_action).length > 0, "Action cannot be empty");
        
        // Update product status
        products[_productId].status = _newStatus;
        
        // If status is harvested, record harvest date
        if (_newStatus == ProductStatus.Harvested) {
            products[_productId].harvestedDate = block.timestamp;
        }
        
        // Add supply chain step
        supplyChainHistory[_productId].push(SupplyChainStep({
            actor: msg.sender,
            role: users[msg.sender].role,
            timestamp: block.timestamp,
            location: _location,
            action: _action,
            additionalInfo: _additionalInfo
        }));
        
        emit ProductStatusUpdated(_productId, _newStatus, msg.sender, block.timestamp);
        emit SupplyChainStepAdded(_productId, msg.sender, _action, block.timestamp);
    }
    
    /**
     * @dev Core Function 3: Get complete supply chain history of a product
     * @param _productId ID of the product
     * @return Product information and complete supply chain history
     */
    function getProductHistory(uint256 _productId) 
        public 
        view 
        productExists(_productId) 
        returns (
            Product memory product,
            SupplyChainStep[] memory history
        ) 
    {
        return (products[_productId], supplyChainHistory[_productId]);
    }
    
    // Additional utility functions
    
    /**
     * @dev Register a new user in the system
     * @param _name Name of the user/organization
     * @param _role Role of the user in the supply chain
     * @param _location Location of the user
     */
    function registerUser(
        string memory _name,
        UserRole _role,
        string memory _location
    ) public {
        require(_role != UserRole.None, "Invalid role");
        require(bytes(_name).length > 0, "Name cannot be empty");
        require(bytes(_location).length > 0, "Location cannot be empty");
        require(users[msg.sender].userAddress == address(0), "User already registered");
        
        users[msg.sender] = User({
            userAddress: msg.sender,
            name: _name,
            role: _role,
            location: _location,
            isVerified: false,
            registrationDate: block.timestamp
        });
        
        userAddresses.push(msg.sender);
        roleCount[_role]++;
        
        emit UserRegistered(msg.sender, _name, _role, block.timestamp);
    }
    
    /**
     * @dev Verify a user (only owner can verify)
     * @param _userAddress Address of the user to verify
     */
    function verifyUser(address _userAddress) public onlyOwner {
        require(users[_userAddress].userAddress != address(0), "User not registered");
        require(!users[_userAddress].isVerified, "User already verified");
        
        users[_userAddress].isVerified = true;
        authorizedUsers[_userAddress] = true;
        
        emit UserVerified(_userAddress, block.timestamp);
    }
    
    /**
     * @dev Get products by farmer
     * @param _farmer Address of the farmer
     * @return Array of product IDs owned by the farmer
     */
    function getProductsByFarmer(address _farmer) 
        public 
        view 
        returns (uint256[] memory) 
    {
        uint256 count = 0;
        
        // Count farmer's products
        for (uint256 i = 0; i < productIds.length; i++) {
            if (products[productIds[i]].farmer == _farmer) {
                count++;
            }
        }
        
        // Create result array
        uint256[] memory farmerProducts = new uint256[](count);
        uint256 index = 0;
        
        for (uint256 i = 0; i < productIds.length; i++) {
            if (products[productIds[i]].farmer == _farmer) {
                farmerProducts[index] = productIds[i];
                index++;
            }
        }
        
        return farmerProducts;
    }
    
    /**
     * @dev Get products by status
     * @param _status Status to filter by
     * @return Array of product IDs with the specified status
     */
    function getProductsByStatus(ProductStatus _status) 
        public 
        view 
        returns (uint256[] memory) 
    {
        uint256 count = 0;
        
        // Count products with status
        for (uint256 i = 0; i < productIds.length; i++) {
            if (products[productIds[i]].status == _status) {
                count++;
            }
        }
        
        // Create result array
        uint256[] memory statusProducts = new uint256[](count);
        uint256 index = 0;
        
        for (uint256 i = 0; i < productIds.length; i++) {
            if (products[productIds[i]].status == _status) {
                statusProducts[index] = productIds[i];
                index++;
            }
        }
        
        return statusProducts;
    }
    
    /**
     * @dev Verify if a product is organic
     * @param _productId ID of the product
     * @return Whether the product is organic
     */
    function verifyOrganic(uint256 _productId) 
        public 
        view 
        productExists(_productId) 
        returns (bool) 
    {
        return products[_productId].isOrganic;
    }
    
    /**
     * @dev Get user information
     * @param _userAddress Address of the user
     * @return User information
     */
    function getUserInfo(address _userAddress) 
        public 
        view 
        returns (User memory) 
    {
        return users[_userAddress];
    }
    
    /**
     * @dev Get all product IDs
     * @return Array of all product IDs
     */
    function getAllProducts() public view returns (uint256[] memory) {
        return productIds;
    }
    
    /**
     * @dev Internal function to validate status transitions
     * @param _currentStatus Current status of the product
     * @param _newStatus New status to transition to
     * @return Whether the transition is valid
     */
    function _isValidStatusTransition(
        ProductStatus _currentStatus, 
        ProductStatus _newStatus
    ) internal pure returns (bool) {
        if (_currentStatus == ProductStatus.Planted && _newStatus == ProductStatus.Harvested) return true;
        if (_currentStatus == ProductStatus.Harvested && _newStatus == ProductStatus.Processed) return true;
        if (_currentStatus == ProductStatus.Processed && _newStatus == ProductStatus.Packaged) return true;
        if (_currentStatus == ProductStatus.Packaged && _newStatus == ProductStatus.InTransit) return true;
        if (_currentStatus == ProductStatus.InTransit && _newStatus == ProductStatus.AtRetailer) return true;
        if (_currentStatus == ProductStatus.AtRetailer && _newStatus == ProductStatus.Sold) return true;
        
        return false;
    }
}

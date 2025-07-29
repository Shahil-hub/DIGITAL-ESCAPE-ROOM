// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract DigitalEscapeRoomDApp is ERC721, Ownable, ReentrancyGuard {
    
    struct Room {
        string name;
        string description;
        address creator;
        uint256 totalClues;
        mapping(uint256 => string) clues; // clueId => clue text
        mapping(uint256 => string) solutions; // clueId => solution
        string finalAnswer;
        bool isActive;
        uint256 createdAt;
    }
    
    struct Player {
        string username;
        uint256 roomsCompleted;
        uint256 totalScore;
        mapping(uint256 => bool) roomsJoined; // roomId => joined status
        mapping(uint256 => mapping(uint256 => bool)) cluesSolved; // roomId => clueId => solved
    }
    
    mapping(uint256 => Room) public rooms;
    mapping(address => Player) public players;
    mapping(uint256 => address[]) public roomEscapees; // roomId => escapees list
    
    uint256 public totalRooms;
    uint256 private _tokenIds;
    
    event RoomCreated(uint256 indexed roomId, string name, address creator);
    event PlayerJoined(address indexed player, uint256 indexed roomId);
    event ClueUnlocked(address indexed player, uint256 indexed roomId, uint256 clueId);
    event RoomEscaped(address indexed player, uint256 indexed roomId, uint256 score);
    event PlayerRegistered(address indexed player, string username);
    
    constructor() ERC721("EscapeRoomNFT", "ERN") Ownable(msg.sender) {}
    
    // Function 1: Register Player
    function registerPlayer(string memory _username) external {
        require(bytes(_username).length > 0, "Username cannot be empty");
        require(bytes(players[msg.sender].username).length == 0, "Player already registered");
        
        players[msg.sender].username = _username;
        
        emit PlayerRegistered(msg.sender, _username);
    }
    
    // Function 2: Create Escape Room
    function createRoom(
        string memory _name,
        string memory _description,
        string[] memory _clues,
        string[] memory _solutions,
        string memory _finalAnswer
    ) external returns (uint256) {
        require(bytes(players[msg.sender].username).length > 0, "Must register first");
        require(_clues.length == _solutions.length, "Clues and solutions count mismatch");
        require(_clues.length > 0, "Room must have at least one clue");
        require(bytes(_name).length > 0, "Room name required");
        
        totalRooms++;
        uint256 roomId = totalRooms;
        
        Room storage newRoom = rooms[roomId];
        newRoom.name = _name;
        newRoom.description = _description;
        newRoom.creator = msg.sender;
        newRoom.totalClues = _clues.length;
        newRoom.finalAnswer = _finalAnswer;
        newRoom.isActive = true;
        newRoom.createdAt = block.timestamp;
        
        // Store clues and solutions
        for (uint256 i = 0; i < _clues.length; i++) {
            newRoom.clues[i + 1] = _clues[i];
            newRoom.solutions[i + 1] = _solutions[i];
        }
        
        emit RoomCreated(roomId, _name, msg.sender);
        return roomId;
    }
    
    // Function 3: Join Room
    function joinRoom(uint256 _roomId) external {
        require(_roomId > 0 && _roomId <= totalRooms, "Invalid room ID");
        require(rooms[_roomId].isActive, "Room is not active");
        require(bytes(players[msg.sender].username).length > 0, "Must register first");
        require(!players[msg.sender].roomsJoined[_roomId], "Already joined this room");
        
        players[msg.sender].roomsJoined[_roomId] = true;
        
        emit PlayerJoined(msg.sender, _roomId);
    }
    
    // Function 4: Solve Clue
    function solveClue(uint256 _roomId, uint256 _clueId, string memory _answer) external {
        require(_roomId > 0 && _roomId <= totalRooms, "Invalid room ID");
        require(players[msg.sender].roomsJoined[_roomId], "Must join room first");
        require(_clueId > 0 && _clueId <= rooms[_roomId].totalClues, "Invalid clue ID");
        require(!players[msg.sender].cluesSolved[_roomId][_clueId], "Clue already solved");
        
        // Check if answer is correct
        require(
            keccak256(abi.encodePacked(_answer)) == 
            keccak256(abi.encodePacked(rooms[_roomId].solutions[_clueId])),
            "Incorrect answer"
        );
        
        players[msg.sender].cluesSolved[_roomId][_clueId] = true;
        players[msg.sender].totalScore += 10; // Points per clue
        
        // Mint NFT as proof of clue completion
        _tokenIds++;
        _safeMint(msg.sender, _tokenIds);
        
        emit ClueUnlocked(msg.sender, _roomId, _clueId);
    }
    
    // Function 5: Escape Room
    function escapeRoom(uint256 _roomId, string memory _finalAnswer) external nonReentrant {
        require(_roomId > 0 && _roomId <= totalRooms, "Invalid room ID");
        require(players[msg.sender].roomsJoined[_roomId], "Must join room first");
        
        // Check if all clues are solved
        for (uint256 i = 1; i <= rooms[_roomId].totalClues; i++) {
            require(players[msg.sender].cluesSolved[_roomId][i], "All clues must be solved first");
        }
        
        // Check final answer
        require(
            keccak256(abi.encodePacked(_finalAnswer)) == 
            keccak256(abi.encodePacked(rooms[_roomId].finalAnswer)),
            "Incorrect final answer"
        );
        
        // Update player stats
        players[msg.sender].roomsCompleted++;
        uint256 completionBonus = 50; // Bonus points for completing room
        players[msg.sender].totalScore += completionBonus;
        
        // Add to escapees list
        roomEscapees[_roomId].push(msg.sender);
        
        // Mint special completion NFT
        _tokenIds++;
        _safeMint(msg.sender, _tokenIds);
        
        emit RoomEscaped(msg.sender, _roomId, completionBonus);
    }
    
    // View Functions
    function getRoomDetails(uint256 _roomId) external view returns (
        string memory name,
        string memory description,
        address creator,
        uint256 totalClues,
        bool isActive,
        uint256 escapeeCount
    ) {
        require(_roomId > 0 && _roomId <= totalRooms, "Invalid room ID");
        Room storage room = rooms[_roomId];
        
        return (
            room.name,
            room.description,
            room.creator,
            room.totalClues,
            room.isActive,
            roomEscapees[_roomId].length
        );
    }
    
    function getClue(uint256 _roomId, uint256 _clueId) external view returns (string memory) {
        require(_roomId > 0 && _roomId <= totalRooms, "Invalid room ID");
        require(_clueId > 0 && _clueId <= rooms[_roomId].totalClues, "Invalid clue ID");
        require(players[msg.sender].roomsJoined[_roomId], "Must join room first");
        
        return rooms[_roomId].clues[_clueId];
    }
    
    function getPlayerStats(address _player) external view returns (
        string memory username,
        uint256 roomsCompleted,
        uint256 totalScore,
        uint256 nftBalance
    ) {
        return (
            players[_player].username,
            players[_player].roomsCompleted,
            players[_player].totalScore,
            balanceOf(_player)
        );
    }
    
    function hasPlayerSolvedClue(address _player, uint256 _roomId, uint256 _clueId) external view returns (bool) {
        return players[_player].cluesSolved[_roomId][_clueId];
    }
    
    function getRoomEscapees(uint256 _roomId) external view returns (address[] memory) {
        require(_roomId > 0 && _roomId <= totalRooms, "Invalid room ID");
        return roomEscapees[_roomId];
    }
    
    // Admin function to deactivate room
    function deactivateRoom(uint256 _roomId) external {
        require(_roomId > 0 && _roomId <= totalRooms, "Invalid room ID");
        require(msg.sender == rooms[_roomId].creator || msg.sender == owner(), "Not authorized");
        
        rooms[_roomId].isActive = false;
    }
}

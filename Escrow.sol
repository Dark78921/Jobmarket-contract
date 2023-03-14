// SPDX-License-Identifier: MIT
/*
    Escrow / 2022
*/
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721ReceiverUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract Escrow is
    Initializable,
    IERC721ReceiverUpgradeable,
    OwnableUpgradeable
{
    IERC20Upgradeable iERC20;
    IERC721Upgradeable iERC721;

    struct EscrowInfo {
        uint256 id;
        address fHolder;
        uint256[] fTokenIds;
        uint256 fAmount;
        address sHolder;
        uint256[] sTokenIds;
        uint256 sAmount;
        bool isConfirmed;
    }

    EscrowInfo[] escrowInfos;

    bool isInitialized;

    event escrowCreated(
        uint256 escrowId,
        address fHolder,
        uint256[] fTokenIds,
        uint256 fAmount,
        address sHolder,
        uint256[] sTokenIds,
        uint256 sAmount
    );
    event escrowConfirmed(
        uint256 escrowId,
        address fHolder,
        uint256[] fTokenIds,
        uint256 fAmount,
        address sHolder,
        uint256[] sTokenIds,
        uint256 sAmount
    );
    event escrowWithdrawn(
        uint256 escrowId,
        address fHolder,
        uint256[] fTokenIds,
        uint256 fAmount,
        address sHolder,
        uint256[] sTokenIds,
        uint256 sAmount
    );

    function initialize(IERC20Upgradeable _iERC20, IERC721Upgradeable _iERC721)
        public
        initializer
    {
        iERC20 = _iERC20;
        iERC721 = _iERC721;
        isInitialized = true;
    }

    function makeEscrow(
        address _fHolder,
        uint256[] memory _fTokenIds,
        uint256 _fAmount,
        address _sHolder,
        uint256[] memory _sTokenIds,
        uint256 _sAmount
    ) external {
        require(isInitialized == true, "Contract is not initialized!");
        require(_fHolder == msg.sender, "Invalid address!");
        require(_fAmount == 0 || _sAmount == 0, "Invalid amount!");
        require(_fAmount != 0 || _fTokenIds.length != 0, "Invalid request!");
        require(_sAmount != 0 || _sTokenIds.length != 0, "Invalid request!");
        require(
            iERC20.balanceOf(_fHolder) >= _fAmount,
            "No sufficient amount!"
        );

        for (uint256 i = 0; i < _fTokenIds.length; i++) {
            require(
                iERC721.ownerOf(_fTokenIds[i]) == _fHolder,
                "Invalid owner!"
            );
        }

        for (uint256 j = 0; j < _sTokenIds.length; j++) {
            require(
                iERC721.ownerOf(_sTokenIds[j]) == _sHolder,
                "Invalid owner!"
            );
        }

        if (_fTokenIds.length != 0) {
            for (uint256 i = 0; i < _fTokenIds.length; i++) {
                iERC721.safeTransferFrom(
                    _fHolder,
                    address(this),
                    _fTokenIds[i]
                );
            }
        }

        if (_fAmount != 0) {
            iERC20.transferFrom(_fHolder, address(this), _fAmount);
        }

        uint256 _escrowId = escrowInfos.length + 1;
        EscrowInfo memory escrowInfo = EscrowInfo(
            _escrowId,
            _fHolder,
            _fTokenIds,
            _fAmount,
            _sHolder,
            _sTokenIds,
            _sAmount,
            false
        );
        escrowInfos.push(escrowInfo);
        emit escrowCreated(
            _escrowId,
            _fHolder,
            _fTokenIds,
            _fAmount,
            _sHolder,
            _sTokenIds,
            _sAmount
        );
    }

    function confirmEscrow(address _confirmer, uint256 _escrowId) external {
        require(isInitialized == true, "Contract is not initialized!");
        EscrowInfo memory escrowInfo = escrowInfos[_escrowId - 1];
        require(escrowInfo.isConfirmed == false, "Aleady confirmed!");
        require(_confirmer == escrowInfo.sHolder, "Incorrect confirmer!");
        uint256[] memory tokenIds = escrowInfo.sTokenIds;
        require(
            iERC20.balanceOf(_confirmer) >= escrowInfo.sAmount,
            "No sufficient amount!"
        );

        for (uint256 i = 0; i < tokenIds.length; i++) {
            require(
                iERC721.ownerOf(tokenIds[i]) == _confirmer,
                "Invalid owner"
            );
        }

        if (escrowInfo.sTokenIds.length > 0) {
            for (uint256 i = 0; i < escrowInfo.sTokenIds.length; i++) {
                iERC721.safeTransferFrom(
                    escrowInfo.sHolder,
                    escrowInfo.fHolder,
                    escrowInfo.sTokenIds[i]
                );
            }
        }

        if (escrowInfo.sAmount > 0) {
            iERC20.transferFrom(
                escrowInfo.sHolder,
                escrowInfo.fHolder,
                escrowInfo.sAmount
            );
        }

        if (escrowInfo.fTokenIds.length > 0) {
            for (uint256 j = 0; j < escrowInfo.fTokenIds.length; j++) {
                iERC721.safeTransferFrom(
                    address(this),
                    escrowInfo.sHolder,
                    escrowInfo.fTokenIds[j]
                );
            }
        }

        if (escrowInfo.fAmount > 0) {
            iERC20.approve(address(this), escrowInfo.fAmount);
            iERC20.transferFrom(
                address(this),
                escrowInfo.sHolder,
                escrowInfo.fAmount
            );
        }

        escrowInfos[_escrowId - 1].isConfirmed = true;

        emit escrowConfirmed(
            _escrowId,
            escrowInfo.fHolder,
            escrowInfo.fTokenIds,
            escrowInfo.fAmount,
            escrowInfo.sHolder,
            escrowInfo.sTokenIds,
            escrowInfo.sAmount
        );
    }

    function getEscrowInfo(uint256 _id)
        external
        view
        returns (
            address,
            uint256[] memory,
            uint256,
            address,
            uint256[] memory,
            uint256
        )
    {
        EscrowInfo memory escrowInfo = escrowInfos[_id - 1];
        return (
            escrowInfo.fHolder,
            escrowInfo.fTokenIds,
            escrowInfo.fAmount,
            escrowInfo.sHolder,
            escrowInfo.sTokenIds,
            escrowInfo.sAmount
        );
    }

    function withdrawEscrow(uint256 _escrowId, address _address) external {
        require(msg.sender == _address, "Invalid request!");
        EscrowInfo memory escrowInfo = escrowInfos[_escrowId - 1];
        require(_address == escrowInfo.fHolder, "Invalid owner!");

        if (escrowInfo.fTokenIds.length > 0) {
            for (uint256 i = 0; i < escrowInfo.fTokenIds.length; i++) {
                iERC721.safeTransferFrom(
                    address(this),
                    escrowInfo.fHolder,
                    escrowInfo.fTokenIds[i]
                );
            }
        }

        if (escrowInfo.fAmount > 0) {
            iERC20.approve(address(this), escrowInfo.fAmount);
            iERC20.transferFrom(
                address(this),
                escrowInfo.fHolder,
                escrowInfo.fAmount
            );
        }

        emit escrowWithdrawn(
            _escrowId,
            escrowInfo.fHolder,
            escrowInfo.fTokenIds,
            escrowInfo.fAmount,
            escrowInfo.sHolder,
            escrowInfo.sTokenIds,
            escrowInfo.sAmount
        );
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes memory
    ) public virtual override returns (bytes4) {
        return this.onERC721Received.selector;
    }
}

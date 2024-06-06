// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract OwnedComposer {
    address parentAddress;

    constructor() {
        parentAddress = msg.sender;
    }
}

contract Composer is OwnedComposer {
    enum Commands {
        UNSET,
        TEMPO,
        DUTY_CYCLE,
        OCTAVE,
        NOTE_TYPE,
        REST,
        NOTE,
        SOUND_LOOP_RET,
        NEW_LOOP
    }
    struct Command {
        Commands cmd;
        uint8 valueIndex;
    }

    constructor() OwnedComposer() {}

    uint256 currentChannelIndex = 0;
    uint8 hasChannelLoop = 0;

    Command currentCommand;

    function getNextOptions() public view returns (uint) {
        if (currentCommand.cmd == Commands.UNSET) 
            return uint8(type(Commands).max) - hasChannelLoop;

        return
            uint8(
                (getCommandOptions(currentCommand.cmd) >>
                    (currentCommand.valueIndex * 8)) & 0xff
            );
    }

    function startNewChannel() internal returns (bool) {
        hasChannelLoop = 0;
        currentCommand = Command(Commands.UNSET, 0);

        if (currentChannelIndex == 2) {
            currentChannelIndex = 0;
            return true;
        }

        currentChannelIndex += 1;

        return false;
    }

    function getCommandOptions(Commands cmd) internal pure returns (uint256) {
        if (cmd == Commands.TEMPO) return 0x0f;
        if (cmd == Commands.DUTY_CYCLE) return 0x04;
        if (cmd == Commands.OCTAVE) return 0x08;
        if (cmd == Commands.NOTE_TYPE) return 0x0f0f;
        if (cmd == Commands.REST) return 0x0f;
        if (cmd == Commands.NOTE) return 0x0f0c;

        return 0x00;
    }

    function applyOption(uint optionIndex) external returns (bool) {
        require(msg.sender == parentAddress);

        if (optionIndex >= getNextOptions()) return false; // invalid option

        if (currentCommand.cmd == Commands.UNSET) {
            currentCommand.cmd = Commands(optionIndex + 1);
        } else {
            currentCommand.valueIndex += 1;
        }

        if (
            getCommandOptions(currentCommand.cmd) <
            (1 << (8 * currentCommand.valueIndex))
        ) return resetCommand();

        return false;
    }

    function resetCommand() internal returns (bool) {
        if (currentCommand.cmd == Commands.SOUND_LOOP_RET) {
            return startNewChannel();
        }

        if (currentCommand.cmd == Commands.NEW_LOOP) hasChannelLoop = 1;

        currentCommand = Command(Commands.UNSET, 0);

        return false;
    }
}


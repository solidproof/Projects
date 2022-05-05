//SPDX-License-Identifier: LicenseRef-LICENSE
pragma solidity ^0.8.0;

library IDOStates {
    enum IDOState {
        UNDER_MODERATION,
        IN_VOTING,
        IN_FUNDING,
        LAUNCHED,
        REJECTED, // rejected by moderator
        FAILED, // Failed in voting state
        CANCELLED // Cancelled because not reached soft-cap or owner cancelled because of some issues
    }

    function validateState(IDOState _oldState, IDOState _newState) internal pure {

        require(_newState != IDOState.UNDER_MODERATION, 'IDOStates: Cannot update state to UNDER_MODERATION');

        if(_newState == IDOState.IN_VOTING) {
            require(_oldState == IDOState.UNDER_MODERATION, 'IDOStates: Only UNDER_MODERATION to IN_VOTING allowed');
        }

        if(_newState == IDOState.IN_FUNDING) {
            require(_oldState == IDOState.IN_VOTING || _oldState == IDOState.UNDER_MODERATION, 'IDOStates: Only IN_VOTING to IN_FUNDING or UNDER_MODERATION to IN_FUNDING allowed');
        }

        if(_newState == IDOState.LAUNCHED) {
            require(_oldState == IDOState.IN_FUNDING, 'IDOStates: Only IN_FUNDING to LAUNCHED allowed');
        }

        if(_newState == IDOState.REJECTED) {
            require(_oldState == IDOState.UNDER_MODERATION, 'IDOStates: Only UNDER_MODERATION to REJECTED allowed');
        }

        if(_newState == IDOState.FAILED) {
            require(_oldState == IDOState.UNDER_MODERATION
                || _oldState == IDOState.IN_VOTING, 'IDOStates: Only UNDER_MODERATION, IN_VOTING to FAILED allowed');
        }

        if(_newState == IDOState.CANCELLED) {
            require(_oldState == IDOState.IN_FUNDING, 'IDOStates: Only IN_FUNDING to CANCELLED allowed');
        }

//        _oldState = _newState;
    }
}

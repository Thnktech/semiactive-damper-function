function cfg = project_config()
%PROJECT_CONFIG Project-wide settings. The only place a vehicle is named (D13).
%   cfg = PROJECT_CONFIG() returns a struct with:
%     vehicle - name of the vehicle used for all verdicts (reference, D12/D14)
%
%   To run another vehicle, pass its name to GET_VEHICLE instead of editing
%   this file. Changing cfg.vehicle changes the reference vehicle and is a
%   design decision (see docs/DECISIONS.md, D13 notes).

% The reference vehicle: all requirement verdicts, the MiL logs and the
% generated code use it (D12, D14). One place, so no script hard-codes a vehicle.
cfg.vehicle = 'sedan_ref';
end

function cfg = project_config()
%PROJECT_CONFIG Project-wide settings. The only place a vehicle is named (D13).
%   cfg = PROJECT_CONFIG() returns a struct with:
%     vehicle - name of the vehicle used for all verdicts (reference, D12/D14)
%
%   To run another vehicle, pass its name to GET_VEHICLE instead of editing
%   this file. Changing cfg.vehicle changes the reference vehicle and is a
%   design decision (see docs/DECISIONS.md, D13 notes).

cfg.vehicle = 'sedan_ref';
end

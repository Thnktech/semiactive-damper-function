function V = vehicle_struct(name, label, source)
%VEHICLE_STRUCT Empty vehicle struct with the common fields (D13).
%   V = VEHICLE_STRUCT(name, label, source) returns a struct whose numeric
%   fields are NaN, to be filled by a vehicle file.
%
%   Fields (per corner):
%     name           vehicle ID, e.g. 'sedan_ref'
%     label          'published' | 'scaled variant (PA)' | 'private'
%     ms, mu         sprung / unsprung mass                 [kg]
%     ks, kt         suspension / tire stiffness            [N/m]
%     c_min, c_max   semi-active damping range              [N*s/m]
%     c_passive      passive baseline damping               [N*s/m]
%     f_body_target, f_wheel_target
%                    design targets for scaled variants     [Hz] (NaN otherwise)
%     source         citation or decision reference

% Numbers start as NaN: a value a vehicle file forgets stays NaN and is caught
% by GET_VEHICLE's validation; DAMPING_RULE fills only damping values still NaN.
V = struct('name', name, 'label', label, ...
    'ms', NaN, 'mu', NaN, 'ks', NaN, 'kt', NaN, ...
    'c_min', NaN, 'c_max', NaN, 'c_passive', NaN, ...
    'f_body_target', NaN, 'f_wheel_target', NaN, ...
    'source', source);
end

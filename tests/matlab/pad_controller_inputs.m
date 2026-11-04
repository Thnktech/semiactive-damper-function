function u = pad_controller_inputs(u)
%PAD_CONTROLLER_INPUTS Complete an input matrix for the v2 controller (D36, D39).
%   u = PAD_CONTROLLER_INPUTS(u) appends zero columns until u has the 9
%   controller inputs: zs_dot, zu_dot, fault_flag, mode, zs, zu, zr, F_d,
%   zr_preview.
%
%   Why zeros: a test written for v1 drives only the first four inputs. Zero
%   positions and zero damper force mean "vehicle at static equilibrium",
%   and the v1 laws (modes 0-3) do not read inputs 5-8 at all, so every v1
%   test keeps its meaning. A zero road preview is a flat road ahead, read
%   only by the preview MPC (mode 6). A test of the preview slot passes all
%   9 columns.

n = 9;
if size(u, 2) > n
    error('pad_controller_inputs:width', 'Controller has %d inputs, got %d columns.', n, size(u, 2));
end
u = [u, zeros(size(u, 1), n - size(u, 2))];
end

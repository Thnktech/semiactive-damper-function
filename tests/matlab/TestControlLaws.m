classdef TestControlLaws < matlab.unittest.TestCase
    %TESTCONTROLLAWS Control-law slots of controller.slx against hand-computed values (M3).
    %   The controller is driven alone with CONSTANT inputs; after settling,
    %   i_cmd is compared with the current computed by hand:
    %     c_req -> clip to [c_min, c_max] -> inverse damper map -> current.

    properties (Constant)
        Model = 'controller'
    end

    methods (TestClassSetup)
        function loadModel(tc)
            load_system(tc.Model);
            tc.addTeardown(@() close_system(tc.Model, 0));
        end
    end

    methods (Test)
        % ---------- Law_1_Skyhook (mode 1) ----------
        function skyhook_clipped_at_c_max(tc)
            % v_rel = 0.1, same direction: c_req = c_sky*0.2/0.1 = 2*c_max -> clipped to c_max
            P = setup_params();
            tc.verifyEqual(tc.settled(P, 0.2, 0.1, 1), P.I_max, 'AbsTol', 1e-12);
        end

        function skyhook_proportional_region(tc)
            % v_rel = 0.3: c_req = c_sky*0.05/0.3, inside [c_min, c_max]
            P = setup_params();
            c = P.c_sky*0.05/0.3;
            tc.assertTrue(c > P.c_min && c < P.c_max, 'Test point must lie inside the damping range');
            tc.verifyEqual(tc.settled(P, 0.05, -0.25, 1), current(P, c), 'AbsTol', 1e-12, ...
                sprintf('c_req = %.1f N*s/m', c));
        end

        function skyhook_cannot_act_goes_soft(tc)
            % zs_dot and v_rel opposite: a damper cannot push like skyhook -> c_min
            P = setup_params();
            tc.verifyEqual(tc.settled(P, 0.2, 0.3, 1), P.I_min, 'AbsTol', 1e-12);
        end

        function REQ_F_05_vrel_zero_is_finite_and_soft(tc)
            % v_rel = 0 exactly: no division by zero, finite output, c_min
            P = setup_params();
            Y = tc.runController(P, 0.1, 0.1, 1);
            tc.verifyTrue(all(isfinite(Y.i_cmd)), 'i_cmd must stay finite (REQ-F-05)');
            tc.verifyEqual(Y.i_cmd(end), P.I_min, 'AbsTol', 1e-12);
        end

        function vrel_below_eps_is_soft(tc)
            % |v_rel| = 0.0005 < eps: guard selects c_min
            P = setup_params();
            tc.verifyEqual(tc.settled(P, 0.1005, 0.1, 1), P.I_min, 'AbsTol', 1e-12);
        end

        function skyhook_sign_symmetric(tc)
            % Skyhook depends on products: flipping all velocities gives the same current
            P = setup_params();
            tc.verifyEqual(tc.settled(P, -0.05, 0.25, 1), tc.settled(P, 0.05, -0.25, 1), 'AbsTol', 1e-12);
        end

        % ---------- mode routing (Multiport Switch, D20, D24) ----------
        function mode_0_is_passive(tc)
            P = setup_params();
            tc.verifyEqual(tc.settled(P, 0.2, 0.1, 0), P.I_passive, 'AbsTol', 1e-12);
        end

        function mode_1_is_skyhook(tc)
            % Same inputs as skyhook_clipped_at_c_max: must differ from passive
            P = setup_params();
            tc.verifyEqual(tc.settled(P, 0.2, 0.1, 1), P.I_max, 'AbsTol', 1e-12, ...
                'mode 1 must select Law_1_Skyhook (Multiport Switch)');
        end

        function unknown_mode_falls_back_to_passive(tc)
            % D20: mode values without a law slot -> default port -> passive
            P = setup_params();
            for m = [7 -1 1.5]
                tc.verifyEqual(tc.settled(P, 0.2, 0.1, m), P.I_passive, 'AbsTol', 1e-12, ...
                    sprintf('mode = %g must fall back to passive', m));
            end
        end
    end

    methods
        function i = settled(tc, P, zs_dot, zu_dot, mode)
            Y = tc.runController(P, zs_dot, zu_dot, mode);
            i = Y.i_cmd(end);
        end

        function Y = runController(tc, P, zs_dot, zu_dot, mode)
            t = (0:1e-3:0.05)';                       % 50 ms: well past any settling
            u = [zs_dot zu_dot 0 mode] .* ones(numel(t), 4);
            in = Simulink.SimulationInput(tc.Model);
            in = in.setVariable('P', P);
            in = in.setExternalInput([t u]);
            in = in.setModelParameter('StopTime', num2str(t(end)), 'SaveOutput', 'on', ...
                'OutputSaveName', 'yout', 'SaveFormat', 'Dataset');
            out = sim(in);
            Y.i_cmd = out.yout{1}.Values.Data(:);
        end
    end
end

function I = current(P, c)
%CURRENT Hand calculation: clip c to [c_min, c_max], then inverse damper map.
c = min(max(c, P.c_min), P.c_max);
I = P.I_min + (c - P.c_min)/(P.c_max - P.c_min)*(P.I_max - P.I_min);
end

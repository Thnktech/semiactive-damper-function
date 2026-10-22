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

        % ---------- Law_2_Groundhook (mode 2) ----------
        function groundhook_proportional_region(tc)
            % v_rel = 0.3, -zu_dot*v_rel > 0: c_req = c_gnd*0.2/0.3
            P = setup_params();
            c = P.c_gnd*0.2/0.3;
            tc.assertTrue(c > P.c_min && c < P.c_max, 'Test point must lie inside the damping range');
            tc.verifyEqual(tc.settled(P, 0.1, -0.2, 2), current(P, c), 'AbsTol', 1e-12, ...
                sprintf('c_req = %.1f N*s/m', c));
        end

        function groundhook_clipped_at_c_max(tc)
            % v_rel = 0.1, zu_dot = -0.3: c_req = c_gnd*0.3/0.1 = 3*c_max -> c_max
            P = setup_params();
            tc.verifyEqual(tc.settled(P, -0.2, -0.3, 2), P.I_max, 'AbsTol', 1e-12);
        end

        function groundhook_cannot_act_goes_soft(tc)
            % -zu_dot = -0.2 and v_rel = +0.1 opposite -> c_min
            P = setup_params();
            tc.verifyEqual(tc.settled(P, 0.3, 0.2, 2), P.I_min, 'AbsTol', 1e-12);
        end

        function groundhook_vrel_zero_is_finite_and_soft(tc)
            % REQ-F-05 for the groundhook slot
            P = setup_params();
            Y = tc.runController(P, -0.1, -0.1, 2);
            tc.verifyTrue(all(isfinite(Y.i_cmd)), 'i_cmd must stay finite (REQ-F-05)');
            tc.verifyEqual(Y.i_cmd(end), P.I_min, 'AbsTol', 1e-12);
        end

        function groundhook_differs_from_skyhook(tc)
            % Same inputs, different laws: proves mode 2 is not routed to skyhook
            P = setup_params();
            tc.verifyNotEqual(tc.settled(P, 0.1, -0.2, 2), tc.settled(P, 0.1, -0.2, 1));
        end

        % ---------- Law_3_Hybrid (mode 3) ----------
        function hybrid_alpha_1_equals_skyhook(tc)
            % alpha = 1: hybrid must reproduce Law_1_Skyhook exactly
            P = setup_params(); P.alpha = 1;
            for x = [0.2 0.1; 0.05 -0.25; 0.2 0.3; 0.1 0.1; -0.05 0.25]'
                tc.verifyEqual(tc.settled(P, x(1), x(2), 3), tc.settled(P, x(1), x(2), 1), 'AbsTol', 1e-12, ...
                    sprintf('alpha = 1 at zs_dot = %g, zu_dot = %g', x(1), x(2)));
            end
        end

        function hybrid_alpha_0_equals_groundhook(tc)
            % alpha = 0: hybrid must reproduce Law_2_Groundhook exactly
            P = setup_params(); P.alpha = 0;
            for x = [0.1 -0.2; -0.2 -0.3; 0.3 0.2; -0.1 -0.1; 0.2 0.1]'
                tc.verifyEqual(tc.settled(P, x(1), x(2), 3), tc.settled(P, x(1), x(2), 2), 'AbsTol', 1e-12, ...
                    sprintf('alpha = 0 at zs_dot = %g, zu_dot = %g', x(1), x(2)));
            end
        end

        function hybrid_blend_both_parts_active(tc)
            % zs_dot = 0.1, zu_dot = -0.2 (v_rel = 0.3): both parts act
            P = setup_params();
            c = P.alpha*P.c_sky*0.1/0.3 + (1 - P.alpha)*P.c_gnd*0.2/0.3;
            tc.assertTrue(c > P.c_min && c < P.c_max, 'Test point must lie inside the damping range');
            tc.verifyEqual(tc.settled(P, 0.1, -0.2, 3), current(P, c), 'AbsTol', 1e-12, ...
                sprintf('c_req = %.1f N*s/m', c));
        end

        function hybrid_inactive_part_contributes_zero(tc)
            % zs_dot = 0.2, zu_dot = 0.1: only the skyhook part acts; the groundhook
            % part adds 0 (not c_min): c_req = alpha*c_sky*2 = c_max for alpha = 0.5
            P = setup_params();
            c = P.alpha*P.c_sky*0.2/0.1;
            tc.verifyEqual(tc.settled(P, 0.2, 0.1, 3), current(P, c), 'AbsTol', 1e-12);
        end

        function hybrid_vrel_zero_is_finite_and_soft(tc)
            % REQ-F-05 for the hybrid slot
            P = setup_params();
            Y = tc.runController(P, 0.1, 0.1, 3);
            tc.verifyTrue(all(isfinite(Y.i_cmd)), 'i_cmd must stay finite (REQ-F-05)');
            tc.verifyEqual(Y.i_cmd(end), P.I_min, 'AbsTol', 1e-12);
        end

        % ---------- mode routing (Multiport Switch, D20, D24) ----------
        function law_slot_names_match_indices(tc)
            % D24 convention: subsystem Law_<n>_<Name> is wired to the Multiport port for index n
            mp = find_system([tc.Model '/Control_law'], 'SearchDepth', 1, 'BlockType', 'MultiPortSwitch');
            mp = mp{1};
            idx = str2double(regexp(get_param(mp, 'DataPortIndices'), '-?\d+', 'match'));   % e.g. '{0,1,3}'
            tc.assertGreaterThanOrEqual(numel(idx), 2, 'Could not read the Multiport Switch indices');
            pc = get_param(mp, 'PortConnectivity');
            for p = 2:numel(idx) + 1                             % port 1 is the control input
                src = get_param(pc(p).SrcBlock, 'Name');
                tok = regexp(src, '^Law_(\d+)_', 'tokens', 'once');
                tc.verifyNotEmpty(tok, sprintf('Port for index %d is fed by "%s", not a Law_<n>_ slot', idx(p-1), src));
                if ~isempty(tok)
                    tc.verifyEqual(str2double(tok{1}), idx(p-1), sprintf( ...
                        '"%s" is wired to mode %d: rename it Law_%d_...', src, idx(p-1), idx(p-1)));
                end
            end
        end

        function first_free_slot_falls_back_to_passive(tc)
            % mode 4 has no law (yet): default port -> passive (D20, D24)
            P = setup_params();
            tc.verifyEqual(tc.settled(P, 0.2, 0.1, 4), P.I_passive, 'AbsTol', 1e-12);
        end

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

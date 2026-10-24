classdef TestPlant < matlab.unittest.TestCase
    %TESTPLANT Verifies the hand-built plant model model/plant/plant.slx (D23).
    %   Interface, solver, rest condition, linear dynamics vs the analytic
    %   quarter car for every public vehicle, road-step signs, effect of the
    %   damper current, and tire lift-off.

    properties (Constant)
        Model = 'plant'
        Outputs = {'zs_dot', 'zu_dot', 'zs_ddot', 'susp_travel', 'F_tire_dyn'}
    end

    % linear_dynamics_match_analytic runs once per public vehicle: the plant must
    % be right for every parameter set, not only for the reference.
    properties (TestParameter)
        vehicle = {'sedan_ref', 'small_car', 'suv', 'light_van'}
    end

    methods (TestClassSetup)
        function loadModel(tc)
            load_system(tc.Model);
            tc.addTeardown(@() close_system(tc.Model, 0));
        end
    end

    methods (Test)
        % Port names and order are the interface used by the harness and the scripts:
        % a swapped port would feed the wrong signal without any error.
        function ports_named_and_ordered(tc)
            in  = find_system(tc.Model, 'SearchDepth', 1, 'BlockType', 'Inport');
            out = find_system(tc.Model, 'SearchDepth', 1, 'BlockType', 'Outport');
            tc.verifyEqual(portNames(in),  {'z_r', 'i_cmd'});
            tc.verifyEqual(portNames(out), tc.Outputs);
        end

        % D8: fixed-step ode4 at 1 ms, sample-aligned with the 1 ms controller.
        function solver_fixed_step_1ms(tc)
            tc.verifyEqual(get_param(tc.Model, 'SolverType'), 'Fixed-step');
            tc.verifyEqual(get_param(tc.Model, 'Solver'), 'ode4');
            tc.verifyEqual(str2double(get_param(tc.Model, 'FixedStep')), 1e-3);
        end

        % Flat road: the preloads (D23) must exactly balance gravity, so all outputs
        % stay zero. Any drift means a wrong preload or offset.
        function rest_gives_zero_outputs(tc)
            P = setup_params();
            Y = tc.simulate(P, 2, @(t) 0*t, @(t) P.I_default + 0*t);
            for k = 1:numel(tc.Outputs)
                y = Y.(tc.Outputs{k}).Data;
                tc.verifyLessThan(max(abs(y)), 1e-9, ...
                    sprintf('%s at rest: max |y| = %.3g', tc.Outputs{k}, max(abs(y))));
            end
        end

        % The strongest plant check: the poles of the linearized Simulink model must
        % equal those of the textbook quarter car built from the same P.
        function linear_dynamics_match_analytic(tc, vehicle)
            P = setup_params(vehicle);
            assignin('base', 'P', P);
            sys = linearize(tc.Model);
            lam = eig(sys.A);
            % Expected: quarter car with c at I_default. The actuator-lag pole
            % -1/tau does not appear: at rest v_rel = 0, so the damper force
            % c*v_rel does not depend on c to first order and linearization
            % removes the lag state.
            c0 = P.c_min + (P.c_max - P.c_min)*(P.I_default - P.I_min)/(P.I_max - P.I_min);
            M = diag([P.ms P.mu]);
            K = [P.ks -P.ks; -P.ks P.ks + P.kt];
            C = c0*[1 -1; -1 1];
            A = [zeros(2) eye(2); -M\K -M\C];
            expected = eig(A);
            tc.verifyEqual(sortByValue(lam), sortByValue(expected), 'RelTol', 1e-6, ...
                sprintf('%s: model poles differ from analytic quarter car', vehicle));
        end

        % Signs and settling after a 10 mm road step: body moves up, tire load rises
        % first, everything returns to rest. Catches sign errors in the wiring.
        function road_step_signs_and_settling(tc)
            P = setup_params();
            Y = tc.simulate(P, 6, @(t) 0.01*(t >= 0.5), @(t) P.I_default + 0*t);
            zsd = Y.zs_dot.Data; F = Y.F_tire_dyn.Data; t = Y.zs_dot.Time;
            k = find(abs(zsd) > 1e-4, 1);
            tc.verifyGreaterThan(zsd(k), 0, 'Body must first move up after a road step up');
            k = find(abs(F) > 1, 1);
            tc.verifyGreaterThan(F(k), 0, 'Tire load must first increase after a road step up');
            late = t > 5;
            tc.verifyLessThan(max(abs(zsd(late))), 1e-3, 'Body velocity must settle');
            tc.verifyLessThan(max(abs(Y.susp_travel.Data(late))), 1e-4, 'Travel must return to 0');
            tc.verifyLessThan(max(abs(F(late))), 5, 'Dynamic tire load must return to 0');
        end

        % The current input must really reach the damper: firm (I_max) must settle
        % much faster than soft (I_min). Found a disconnected damper input in M2.
        function current_changes_damping(tc)
            P = setup_params();
            road = @(t) 0.01*(t >= 0.5);
            soft = tc.simulate(P, 4, road, @(t) P.I_min + 0*t);
            firm = tc.simulate(P, 4, road, @(t) P.I_max + 0*t);
            late = soft.zs_dot.Time > 2.5;
            s = max(abs(soft.zs_dot.Data(late)));
            f = max(abs(firm.zs_dot.Data(late)));
            tc.verifyGreaterThan(s, 10*f, sprintf( ...
                'Firm damping must settle faster: late |zs_dot| soft %.2e vs firm %.2e', s, f));
        end

        % A tire can push but not pull (D23): after a 100 mm drop the wheel lifts off,
        % and the tire force never becomes negative.
        function tire_lifts_off_but_never_pulls(tc)
            P = setup_params();
            Y = tc.simulate(P, 3, @(t) -0.1*(t >= 0.5), @(t) P.I_default + 0*t);
            F = Y.F_tire_dyn.Data;
            tc.verifyGreaterThanOrEqual(min(F), -P.F_static - 1e-6, 'Tire force must never be negative (D23)');
            tc.verifyLessThan(min(F), -P.F_static + 1, 'A 100 mm drop must lift the wheel off');
        end
    end

    methods
        % Helper: one plant run with road and current given as functions of time.
        function Y = simulate(tc, P, T, zr, icmd)
            t = (0:1e-3:T)';
            in = Simulink.SimulationInput(tc.Model);
            in = in.setVariable('P', P);
            in = in.setExternalInput([t zr(t) icmd(t)]);
            in = in.setModelParameter('StopTime', num2str(T), 'SaveOutput', 'on', ...
                'OutputSaveName', 'yout', 'SaveFormat', 'Dataset');
            out = sim(in);
            for k = 1:numel(tc.Outputs)
                Y.(tc.Outputs{k}) = out.yout{k}.Values;
            end
        end
    end
end

% Port names sorted by port number (find_system returns them in any order).
function names = portNames(blocks)
nums = cellfun(@(b) str2double(get_param(b, 'Port')), blocks);
[~, order] = sort(nums);
names = get_param(blocks(order), 'Name')';
end

% Sort complex poles by real, then imaginary part, so two pole lists compare.
function v = sortByValue(v)
v = sortrows([real(v) imag(v)]);
end

classdef TestController < matlab.unittest.TestCase
    %TESTCONTROLLER Controller model model/controller/controller.slx, run stand-alone (M3).
    %   The controller is driven directly from MATLAB with its 4 inputs, the
    %   same way the generated C code is driven in M5 (no plant involved).

    properties (Constant)
        Model = 'controller'
        Inputs = {'zs_dot', 'zu_dot', 'fault_flag', 'mode'}
        Outputs = {'i_cmd', 'fault_active'}
        PlantOnly = {'P.ms', 'P.mu', 'P.ks', 'P.kt', 'P.l0', 'P.Rt0', 'P.F_static', 'P.g', 'P.tau'}
    end

    methods (TestClassSetup)
        function loadModel(tc)
            load_system(tc.Model);
            tc.addTeardown(@() close_system(tc.Model, 0));
        end
    end

    methods (Test)
        function ports_match_signals_md(tc)
            % signals.md: names and ORDER; C structs in M5 follow this order
            tc.verifyEqual(portNames(tc.Model, 'Inport'), tc.Inputs);
            tc.verifyEqual(portNames(tc.Model, 'Outport'), tc.Outputs);
        end

        function inputs_are_double_at_1ms(tc)
            % signals.md: all root I/O double, 1 ms; mil_to_sil.md rule 1.3
            for b = find_system(tc.Model, 'SearchDepth', 1, 'BlockType', 'Inport')'
                n = get_param(b{1}, 'Name');
                tc.verifyEqual(get_param(b{1}, 'OutDataTypeStr'), 'double', [n ': data type must be double']);
                tc.verifyEqual(get_param(b{1}, 'SampleTime'), '0.001', [n ': sample time must be 0.001']);
            end
        end

        function REQ_F_02_discrete_1ms(tc)
            % REQ-F-02, D8: fixed-step discrete solver, 1 ms
            tc.verifyEqual(get_param(tc.Model, 'SolverType'), 'Fixed-step');
            tc.verifyEqual(get_param(tc.Model, 'Solver'), 'FixedStepDiscrete', ...
                'Controller must use the discrete solver (no continuous states)');
            tc.verifyEqual(str2double(get_param(tc.Model, 'FixedStep')), 1e-3);
        end

        function single_instance_for_codegen(tc)
            tc.verifyEqual(get_param(tc.Model, 'ModelReferenceNumInstancesAllowed'), 'Single');
        end

        function minimize_artificial_algebraic_loops_D26(tc)
            % D26: per-port analysis, so the output delays (D19) break the loop in the harness
            tc.verifyEqual(get_param(tc.Model, 'ModelReferenceMinAlgLoopOccurrences'), 'on');
        end

        function REQ_F_03_initial_output(tc)
            % REQ-F-03, D19: step 0 returns exactly I_default and 0
            P = setup_params();
            Y = tc.simulate(P, 0.01, zeros(11, 4));
            tc.verifyEqual(Y.i_cmd(1), P.I_default, 'i_cmd(0) must equal I_default exactly');
            tc.verifyEqual(Y.fault_active(1), 0, 'fault_active(0) must be 0');
        end

        function outputs_are_registered_D19(tc)
            % D19: the computed value appears one step later; step 0 is the delay's initial value
            P = setup_params();
            Y = tc.simulate(P, 0.01, zeros(11, 4));
            tc.verifyNotEqual(Y.i_cmd(2), Y.i_cmd(1), 'Output must change after one sample');
        end

        function outputs_are_double(tc)
            % signals.md: all root I/O double (a boolean fault_active would change the C struct in M5)
            P = setup_params();
            t = (0:1e-3:0.01)';
            in = Simulink.SimulationInput(tc.Model);
            in = in.setVariable('P', P);
            in = in.setExternalInput([t zeros(numel(t), 4)]);
            in = in.setModelParameter('StopTime', '0.01', 'SaveOutput', 'on', ...
                'OutputSaveName', 'yout', 'SaveFormat', 'Dataset');
            out = sim(in);
            for k = 1:numel(tc.Outputs)
                tc.verifyClass(out.yout{k}.Values.Data, 'double', [tc.Outputs{k} ' must be double']);
            end
        end

        function passive_mode_settles_at_I_passive(tc)
            % mode 0: c_passive -> Damping_to_current -> I_passive (inverse damper map)
            P = setup_params();
            u = zeros(51, 4);                     % mode 0, no fault, no motion
            Y = tc.simulate(P, 0.05, u);
            tc.verifyEqual(Y.i_cmd(end), P.I_passive, 'AbsTol', 1e-12);
        end

        function no_plant_parameters_inside(tc)
            % M3 rule: the controller uses only its 4 inputs and controller parameters
            blks = find_system(tc.Model, 'LookUnderMasks', 'all', 'Type', 'Block');
            for k = 1:numel(blks)
                dp = get_param(blks{k}, 'DialogParameters');
                if ~isstruct(dp), continue; end
                for f = fieldnames(dp)'
                    v = get_param(blks{k}, f{1});
                    if ~ischar(v), continue; end
                    hit = tc.PlantOnly(cellfun(@(p) ~isempty(regexp(v, [regexptranslate('escape', p) '\>'], 'once')), tc.PlantOnly));
                    tc.verifyEmpty(hit, sprintf('%s.%s uses plant parameter %s', blks{k}, f{1}, strjoin(hit, ', ')));
                end
            end
        end

        function no_logging_blocks_inside(tc)
            % mil_to_sil.md rule 1.5: logging belongs to the harness
            for bt = {'Scope', 'ToWorkspace', 'FromWorkspace', 'Display'}
                b = find_system(tc.Model, 'LookUnderMasks', 'all', 'BlockType', bt{1});
                tc.verifyEmpty(b, sprintf('Remove %s block(s) from the controller: %s', bt{1}, strjoin(b, ', ')));
            end
        end
    end

    methods
        function Y = simulate(tc, P, T, u)
            t = (0:1e-3:T)';
            in = Simulink.SimulationInput(tc.Model);
            in = in.setVariable('P', P);
            in = in.setExternalInput([t u]);
            in = in.setModelParameter('StopTime', num2str(T), 'SaveOutput', 'on', ...
                'OutputSaveName', 'yout', 'SaveFormat', 'Dataset');
            out = sim(in);
            for k = 1:numel(tc.Outputs)
                Y.(tc.Outputs{k}) = out.yout{k}.Values.Data(:);
            end
        end
    end
end

function names = portNames(mdl, type)
b = find_system(mdl, 'SearchDepth', 1, 'BlockType', type);
nums = cellfun(@(x) str2double(get_param(x, 'Port')), b);
[~, order] = sort(nums);
names = get_param(b(order), 'Name')';
end

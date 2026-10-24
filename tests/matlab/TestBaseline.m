classdef TestBaseline < matlab.unittest.TestCase
    %TESTBASELINE Passive baseline (M2): passive current, simulate_plant, committed results.
    %   Checks the committed results file instead of re-running the 9 scenarios (~85 s).

    properties (Constant)
        Scenarios = {'A50', 'A80', 'B50', 'B80', 'C50', 'C80', 'D50', 'D80', 'BUMP'}
    end

    methods (Test)
        % I_passive must map back to exactly c_passive through the damper map, for
        % every vehicle: otherwise 'passive' would not be the D22 damping.
        function passive_current_reproduces_c_passive(tc)
            for v = list_vehicles()
                P = setup_params(v{1});
                c = P.c_min + (P.c_max - P.c_min)*(P.I_passive - P.I_min)/(P.I_max - P.I_min);
                tc.verifyEqual(c, P.c_passive, 'RelTol', 1e-12, v{1});
                tc.verifyTrue(P.I_passive > P.I_min && P.I_passive < P.I_max, ...
                    sprintf('%s: I_passive %.3f A outside current range', v{1}, P.I_passive));
            end
        end

        % One output sample per 1 ms input step: KPIs and logs assume this alignment (D8).
        function simulate_plant_returns_one_sample_per_step(tc)
            P = setup_params();
            [t, zr] = road_iso8608('C', 80, 3, 1);
            Y = simulate_plant(P, t, zr, P.I_passive);
            tc.verifyEqual(Y.t, t, 'AbsTol', 1e-12);
            for f = {'zs_dot', 'zu_dot', 'zs_ddot', 'susp_travel', 'F_tire_dyn'}
                tc.verifySize(Y.(f{1}), size(t), f{1});
            end
        end

        function rougher_road_gives_proportionally_higher_kpi(tc)
            % Linear plant (no lift-off on class C/D, 10 s): RMS doubles per class
            P = setup_params();
            K = cell(1, 2);
            cls = {'C', 'D'};
            for k = 1:2
                [t, zr] = road_iso8608(cls{k}, 80, 10, 1);
                Y = simulate_plant(P, t, zr, P.I_passive);
                K{k} = kpi(Y.t, Y.zs_ddot, Y.F_tire_dyn, Y.susp_travel, P.F_static);
            end
            tc.verifyEqual(K{2}.rms_zs_ddot/K{1}.rms_zs_ddot, 2, 'RelTol', 0.02);
        end

        % The committed CSV is the reference of every later 'x % vs passive': all 9
        % scenarios, the reference vehicle, no NaN.
        function committed_baseline_is_complete(tc)
            T = tc.readBaseline();
            tc.verifyEqual(sort(T.scenario)', sort(tc.Scenarios));
            tc.verifyTrue(all(strcmp(T.vehicle, 'sedan_ref')));
            tc.verifyTrue(all(isfinite([T.rms_zs_ddot; T.rms_F_tire_dyn; T.max_travel_mm])));
        end

        % Physics check of the committed numbers: a rougher road and faster driving
        % must both increase the RMS body acceleration.
        function committed_baseline_is_ordered(tc)
            T = tc.readBaseline();
            for v = [50 80]
                r = arrayfun(@(c) T.rms_zs_ddot(strcmp(T.scenario, sprintf('%s%d', c, v))), 'ABCD');
                tc.verifyTrue(all(diff(r) > 0), sprintf('%d km/h: RMS must rise from A to D', v));
            end
            for c = 'ABCD'
                tc.verifyGreaterThan(T.rms_zs_ddot(strcmp(T.scenario, [c '80'])), ...
                    T.rms_zs_ddot(strcmp(T.scenario, [c '50'])), sprintf('Class %s: 80 km/h > 50 km/h', c));
            end
        end

        % Vehicle name in every file name: private results can then be git-ignored by
        % pattern (*erod*, D21), and results of different cars never overwrite each other.
        function result_files_carry_vehicle_name(tc)
            d = dir(fullfile(tc.baselineDir(), '*.*'));
            d = d(~[d.isdir]);
            tc.assumeNotEmpty(d, 'No baseline results yet');
            for k = 1:numel(d)
                tc.verifySubstring(d(k).name, '_sedan_ref', ...
                    sprintf('%s: result file names must contain the vehicle (D13, D21)', d(k).name));
            end
        end
    end

    methods
        function p = baselineDir(~)
            p = fullfile(matlab.project.rootProject().RootFolder, 'results', 'baseline');
        end

        % Read the committed file instead of re-running 9 scenarios (~85 s); 'assume'
        % skips the test (instead of failing) in a clone where it was never generated.
        function T = readBaseline(tc)
            f = fullfile(tc.baselineDir(), 'kpi_baseline_sedan_ref.csv');
            tc.assumeTrue(isfile(f), 'Run run_baseline() first');
            T = readtable(f, 'TextType', 'char');
        end
    end
end

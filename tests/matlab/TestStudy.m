classdef TestStudy < matlab.unittest.TestCase
    %TESTSTUDY run_study / law_names: the flexible study runner (M3).
    %   Uses short runs and a temporary output folder.

    properties
        Out
    end

    methods (TestMethodSetup)
        % Every test writes into its own temporary folder, deleted afterwards, so
        % tests never change results/ or each other's files.
        function tempOut(tc)
            tc.Out = tempname;
            tc.addTeardown(@() removeIfExists(tc.Out));
        end
    end

    methods (Test)
        % The slot names come from controller.slx; a renamed slot changes all labels.
        function law_names_read_from_model(tc)
            n = law_names();
            tc.verifyEqual(n(0), 'Passive');
            tc.verifyEqual(n(1), 'Skyhook');
            tc.verifyEqual(n(2), 'Groundhook');
            tc.verifyEqual(n(3), 'Hybrid');
        end

        function passive_added_and_deltas_zero(tc)
            S = run_study(struct('name', 't', 'modes', 1, 'roads', {{'A50'}}, 'T', 4, 'outDir', tc.Out));
            tc.verifyEqual(sort(S.T.mode)', [0 1], 'Passive must be added as reference');
            tc.verifyEqual(S.T.d_comfort_pct(S.T.mode == 0), 0);
        end

        function same_numbers_as_run_comparison(tc)
            % The flexible runner and the committed comparison must agree (C80, skyhook)
            S = run_study(struct('name', 't', 'modes', 1, 'roads', {{'C80'}}, 'T', 30, 'outDir', tc.Out));
            C = readtable(fullfile(matlab.project.rootProject().RootFolder, 'results', 'comparison', ...
                'kpi_comparison_sedan_ref.csv'), 'TextType', 'char');
            c = C(strcmp(C.scenario, 'C80') & C.mode == 1, :);
            s = S.T(S.T.mode == 1, :);
            tc.verifyEqual(s.rms_zs_ddot, c.rms_zs_ddot, 'RelTol', 1e-6);
            tc.verifyEqual(s.d_tire_pct, c.d_tire_pct, 'AbsTol', 1e-4);
        end

        % Any class A-D at any speed, lower case accepted; BUMP30 = the bump at 30 km/h.
        function road_codes_parsed(tc)
            S = run_study(struct('name', 't', 'modes', 2, 'roads', {{'b65', 'BUMP30'}}, 'T', 3, 'outDir', tc.Out));
            tc.verifyEqual(unique(S.T.road, 'stable')', {'B65', 'BUMP30'});
            tc.verifyEqual(unique(S.T.speed_kmh)', [30 65]);
        end

        % All five outputs exist and carry the vehicle in their names (D13, D21).
        function files_written_with_vehicle_name(tc)
            run_study(struct('name', 't', 'modes', [1 3], 'roads', {{'A50'}}, 'T', 3, ...
                'timePlotRoads', {{'A50'}}, 'timeWindow', [1 2], 'outDir', tc.Out));
            for f = {'kpi_sedan_ref.csv', 'summary_sedan_ref.md', 'delta_bars_sedan_ref.png', ...
                    'tradeoff_sedan_ref.png', 'time_A50_sedan_ref.png'}
                tc.verifyTrue(isfile(fullfile(tc.Out, f{1})), [f{1} ' missing']);
            end
        end

        % Typos must stop with a clear error before any simulation runs.
        function unknown_mode_and_road_rejected(tc)
            tc.verifyError(@() run_study(struct('modes', 9, 'roads', {{'A50'}}, 'T', 3, 'outDir', tc.Out)), 'run_study:mode');
            tc.verifyError(@() run_study(struct('modes', 1, 'roads', {{'X80'}}, 'T', 3, 'outDir', tc.Out)), 'run_study:road');
        end
    end
end

function removeIfExists(d)
if isfolder(d), rmdir(d, 's'); end
end

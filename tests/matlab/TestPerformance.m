classdef TestPerformance < matlab.unittest.TestCase
    %TESTPERFORMANCE Performance requirements REQ-P-01...06 from closed-loop MiL runs (M4, M8).
    %   Scenarios as defined in requirements/REQ.md: SC-C80 (class C, 80 km/h,
    %   30 s, seed 1, KPIs over t >= 2 s) and SC-BUMP. Reference vehicle unless
    %   stated. Tagged KnownFail: REQ-P-02 (skyhook exceeds the tire-load limit)
    %   and REQ-P-05/06 (the classic MPC cannot meet both limits, D38).

    properties (Constant)
        Skyhook = 1
        MPC = 5
    end

    properties
        C80     % cached KPIs per vehicle: passive and skyhook on SC-C80
    end

    methods (TestClassSetup)
        function setup(tc)
            load_system('harness');
            tc.addTeardown(@() close_system('harness', 0));
            tc.C80 = containers.Map();
        end
    end

    methods (Test, TestTags = {'REQ-P-01'})
        function REQ_P_01_ride_comfort(tc)
            K = tc.c80('sedan_ref');
            red = 100*(1 - K.sky.rms_zs_ddot/K.pas.rms_zs_ddot);
            record_evidence('REQ-P-01', 'TestPerformance/REQ_P_01_ride_comfort', ...
                'RMS body acceleration reduction vs passive (SC-C80, skyhook)', red, '%');
            tc.verifyGreaterThanOrEqual(red, 10, sprintf( ...
                'Comfort: reduction %.1f %% < 10 %% (passive %.3f, skyhook %.3f m/s^2)', ...
                red, K.pas.rms_zs_ddot, K.sky.rms_zs_ddot));
        end
    end

    methods (Test, TestTags = {'REQ-P-02', 'KnownFail'})
        function REQ_P_02_road_holding_penalty(tc)
            K = tc.c80('sedan_ref');
            inc = 100*(K.sky.rms_F_tire_dyn/K.pas.rms_F_tire_dyn - 1);
            record_evidence('REQ-P-02', 'TestPerformance/REQ_P_02_road_holding_penalty', ...
                'RMS dynamic tire load increase vs passive (SC-C80, skyhook)', inc, '%');
            tc.verifyLessThanOrEqual(inc, 10, sprintf( ...
                'Road holding: increase %.1f %% > 10 %% (passive %.1f, skyhook %.1f N). Known failure: strategy to be improved', ...
                inc, K.pas.rms_F_tire_dyn, K.sky.rms_F_tire_dyn));
        end
    end

    methods (Test, TestTags = {'REQ-P-05', 'KnownFail'})
        function REQ_P_05_mpc_ride_comfort(tc)
            K = tc.c80mpc();
            red = 100*(1 - K.mpc.rms_zs_ddot/K.pas.rms_zs_ddot);
            record_evidence('REQ-P-05', 'TestPerformance/REQ_P_05_mpc_ride_comfort', ...
                'RMS body acceleration reduction vs passive (SC-C80, MPC)', red, '%');
            tc.verifyGreaterThanOrEqual(red, 10, sprintf( ...
                'MPC comfort: reduction %.1f %% < 10 %% (passive %.3f, MPC %.3f m/s^2). Known failure: classic MPC cannot meet REQ-P-05 and REQ-P-06 together (D38)', ...
                red, K.pas.rms_zs_ddot, K.mpc.rms_zs_ddot));
        end
    end

    methods (Test, TestTags = {'REQ-P-06', 'KnownFail'})
        function REQ_P_06_mpc_road_holding_penalty(tc)
            K = tc.c80mpc();
            inc = 100*(K.mpc.rms_F_tire_dyn/K.pas.rms_F_tire_dyn - 1);
            record_evidence('REQ-P-06', 'TestPerformance/REQ_P_06_mpc_road_holding_penalty', ...
                'RMS dynamic tire load increase vs passive (SC-C80, MPC)', inc, '%');
            tc.verifyLessThanOrEqual(inc, 10, sprintf( ...
                'MPC road holding: increase %.1f %% > 10 %% (passive %.1f, MPC %.1f N). Known failure: classic MPC cannot meet REQ-P-05 and REQ-P-06 together (D38)', ...
                inc, K.pas.rms_F_tire_dyn, K.mpc.rms_F_tire_dyn));
        end
    end

    methods (Test, TestTags = {'REQ-P-03'})
        function REQ_P_03_suspension_travel(tc)
            P = setup_params();
            [t, zr] = road_bump(0.05, 0.5, 18, 6, 2.5);
            worst = 0; at = 0;
            % "In every mode": all law slots in the model (v2 adds LQR, MPC)
            for m = cell2mat(keys(law_names()))
                Y = simulate_harness(P, t, zr, m);
                K = kpi(Y.t, Y.zs_ddot, Y.F_tire_dyn, Y.susp_travel, P.F_static);
                tc.verifyLessThanOrEqual(K.max_travel_mm, 100, sprintf( ...
                    'Travel on SC-BUMP, mode %d: %.1f mm > 100 mm', m, K.max_travel_mm));
                if K.max_travel_mm > worst, worst = K.max_travel_mm; at = m; end
            end
            record_evidence('REQ-P-03', 'TestPerformance/REQ_P_03_suspension_travel', ...
                sprintf('max suspension travel on SC-BUMP, all modes (worst: mode %d)', at), worst, 'mm');
        end
    end

    methods (Test, TestTags = {'REQ-P-04'})
        function REQ_P_04_robustness_across_vehicles(tc)
            veh = list_vehicles();                     % public vehicles only (D21)
            worst = inf; at = '';
            for v = veh
                K = tc.c80(v{1});
                red = 100*(1 - K.sky.rms_zs_ddot/K.pas.rms_zs_ddot);
                tc.verifyGreaterThanOrEqual(red, 0, sprintf( ...
                    '%s: skyhook worse than passive (%.1f %%)', v{1}, -red));
                if red < worst, worst = red; at = v{1}; end
            end
            record_evidence('REQ-P-04', 'TestPerformance/REQ_P_04_robustness_across_vehicles', ...
                sprintf('smallest comfort reduction vs passive over %d vehicles (%s)', numel(veh), at), worst, '%');
        end
    end

    methods
        function K = c80(tc, vehicle)
            % Passive and skyhook KPIs on SC-C80 for one vehicle, computed once per class
            if ~isKey(tc.C80, vehicle)
                P = setup_params(vehicle);
                [t, zr] = road_iso8608('C', 80, 30, 1);
                Yp = simulate_harness(P, t, zr, 0);
                Ys = simulate_harness(P, t, zr, tc.Skyhook);
                K.pas = kpi(Yp.t, Yp.zs_ddot, Yp.F_tire_dyn, Yp.susp_travel, P.F_static);
                K.sky = kpi(Ys.t, Ys.zs_ddot, Ys.F_tire_dyn, Ys.susp_travel, P.F_static);
                tc.C80(vehicle) = K;
            end
            K = tc.C80(vehicle);
        end

        function K = c80mpc(tc)
            % Passive and MPC KPIs on SC-C80, reference vehicle, MPC run once per
            % class (kept in the same handle map: test methods run on copies)
            K = tc.c80('sedan_ref');
            if ~isKey(tc.C80, 'mpc:sedan_ref')
                P = setup_params('sedan_ref');
                [t, zr] = road_iso8608('C', 80, 30, 1);
                Ym = simulate_harness(P, t, zr, tc.MPC);
                tc.C80('mpc:sedan_ref') = kpi(Ym.t, Ym.zs_ddot, Ym.F_tire_dyn, Ym.susp_travel, P.F_static);
            end
            K.mpc = tc.C80('mpc:sedan_ref');
        end
    end
end

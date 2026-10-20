classdef TestVehicles < matlab.unittest.TestCase
    %TESTVEHICLES Vehicle parameter files, selector and natural frequencies (M2).
    %   Private vehicles (D21) are tested only when present in this clone.

    methods (Test)
        function selector_returns_reference_vehicle(tc)
            cfg = project_config();
            V = get_vehicle();
            tc.verifyEqual(V.name, cfg.vehicle);
            tc.verifyEqual(V.name, 'sedan_ref');
        end

        function reference_matches_D14(tc)
            V = get_vehicle('sedan_ref');
            tc.verifyEqual([V.ms V.mu V.ks V.kt], [230 34.5 14559 150190], 'AbsTol', 1e-9);
            [fb, fw] = natural_frequencies(V);
            tc.verifyEqual(fb, 1.21, 'AbsTol', 0.005, sprintf('f_body = %.4f Hz', fb));
            tc.verifyEqual(fw, 11.0, 'AbsTol', 0.01,  sprintf('f_wheel = %.4f Hz', fw));
        end

        function scaled_variants_hit_targets(tc)
            for n = {'small_car', 'suv', 'light_van'}
                V = get_vehicle(n{1});
                [fb, fw] = natural_frequencies(V);
                tc.verifyEqual([fb fw], [V.f_body_target V.f_wheel_target], 'RelTol', 1e-9, ...
                    sprintf('%s: %.6f / %.6f Hz', V.name, fb, fw));
            end
        end

        function scaled_variants_match_D16_table(tc)
            % [ks kt] in N/m as documented in docs/DECISIONS.md, D16 (rounded)
            d16 = struct('small_car', [14989 157621], 'suv', [24259 231342], ...
                'light_van', [45633 320305]);
            for n = fieldnames(d16)'
                V = get_vehicle(n{1});
                tc.verifyEqual([V.ks V.kt], d16.(n{1}), 'AbsTol', 1, ...
                    sprintf('%s differs from D16', n{1}));
            end
        end

        function all_vehicles_plausible(tc)
            [pub, priv] = list_vehicles();
            for n = [pub, priv]
                V = get_vehicle(n{1});
                [fb, fw] = natural_frequencies(V);
                tc.verifyTrue(fb >= 0.8 && fb <= 2.0, sprintf('%s: f_body %.2f Hz outside 0.8-2.0', V.name, fb));
                tc.verifyTrue(fw >= 8 && fw <= 20, sprintf('%s: f_wheel %.2f Hz outside 8-20', V.name, fw));
                tc.verifyLessThan(V.c_min, V.c_passive);
                tc.verifyLessThan(V.c_passive, V.c_max);
            end
        end

        function damping_rule_zetas(tc)
            V = get_vehicle('sedan_ref');
            c_crit = 2*sqrt(V.ks*V.ms);
            tc.verifyEqual([V.c_min V.c_passive V.c_max]/c_crit, [0.1 0.3 0.8], 'AbsTol', 1e-12);
        end

        function unknown_vehicle_errors(tc)
            tc.verifyError(@() get_vehicle('no_such_car'), 'vehicles:unknown');
        end

        function missing_private_vehicle_errors_clearly(tc)
            [~, priv] = list_vehicles();
            tc.assumeFalse(ismember('erod_front', priv), 'Private eROD files present; test applies to clean clones.');
            tc.verifyError(@() get_vehicle('erod_front'), 'vehicles:privateMissing');
        end

        function private_vehicles_load_when_present(tc)
            [~, priv] = list_vehicles();
            tc.assumeNotEmpty(priv, 'No private vehicles in this clone (D21).');
            for n = priv
                V = get_vehicle(n{1});
                tc.verifyEqual(V.label, 'private');
            end
        end
    end
end

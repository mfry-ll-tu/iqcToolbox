%% Requirements:
%    1. Ulft.blkdiag shall perform the diagonal concatenation operation between multiple LFTs, wherein
%   	a. the a, b, c, d matrices of the output LFT are defined by the a, b, c, d matrices of the input LFTs, as in:
%           - a_out = blkdiag(a1, a2, ...)
%           - b_out = blkdiag(b1, b2, ...)
%           - c_out = blkdiag(c1, c2, ...)
%           - d_out = blkdiag(d1, d2, ...)
%       b. the delta objects of the output LFT are a concatenation of the deltas of the input LFTs, respecting the same order
%       c. Reordering Deltas is necessitated when any of the following conditions hold:
%           - DeltaDelayZ appears in any operand LFT besides the first
%           - DeltaIntegrator appears in any operand LFT besides the first
%           - any operand LFT contains the same Delta
%    2. Ulft.blkdiag shall output an LFT that does not have duplicates of the same delta, disturbance, or performance.
%    3. Ulft.blkdiag shall be capable of taking one input argument that is not a Ulft object, as long as the input argument can be converted to a Ulft. 
%    4. If an input is not convertible to a Ulft object, an error shall be thrown. Objects convertible to Ulfts are:
%        - doubles
%        - Delta objects
%        - ss objects
%    5. If the Ulft.blkdiag operands have different horizon_periods, Ulft.blkdiag shall ensure that the output Ulft shall have a resulting horizon_period that is consistent with the horizon_periods of both operands.
%    6. Ulft.blkdiag shall output an Ulft whose performances and disturbances have adjusted channels that reflect the position of each input Ulft within the output Ulft.

%%
%  Copyright (c) 2021 Massachusetts Institute of Technology 
%  SPDX-License-Identifier: GPL-2.0
%%
%% Test class for Ulft.blkdiag.
classdef testUlftBlkdiag < matlab.unittest.TestCase
    
    methods (TestMethodSetup)
        function seedAndReportRng(testCase)
            seed = floor(posixtime(datetime('now')));
            rng('default');
            rng(seed);
            diagnose_str = ...
                sprintf(['Random inputs may be regenerated by calling: \n',...
                         '>> rng(%10d) \n',...
                         'before running the remainder of the test''s body'],...
                        seed);
            testCase.onFailure(@() fprintf(diagnose_str));
        end    
    end
   
    methods(Test)
        function testUlftBlkdiagOutputNoDuplicate(testCase)
            temp_a = cell(1, 3);
            temp_b = cell(1, 3);
            temp_c = cell(1, 3);
            temp_d = cell(1, 3);
            for i = 1:3
                temp_a{i} = i*ones(4, 4);
                temp_b{i} = i*ones(4, 1);
                temp_c{i} = i*ones(1, 4);
                temp_d{i} = i;
            end
            [a1, a2, a3] = deal(temp_a{1}, temp_a{2}, temp_a{3});
            [b1, b2, b3] = deal(temp_b{1}, temp_b{2}, temp_b{3});
            [c1, c2, c3] = deal(temp_c{1}, temp_c{2}, temp_c{3});
            [d1, d2, d3] = deal(temp_d{1}, temp_d{2}, temp_d{3});
            delta1 = DeltaSlti('b', 4);
            delta2 = DeltaSlti('a', 4);
            delta3 = DeltaDelayZ(4);
            
            lft1 = Ulft(a1, b1, c1, d1, delta1);
            lft2 = Ulft(a2, b2, c2, d2, delta2);
            lft3 = Ulft(a3, b3, c3, d3, delta3);
            
            a_out = {blkdiag(a3, a1, a2)};
            b_out = {blkdiag(b3, b1, b2)};
            c_out = {blkdiag(c3, c1, c2)};
            d_out = {blkdiag(d3, d1, d2)};
            deltas_out = SequenceDelta(delta3, delta1, delta2);
            diag_lft = blkdiag(lft3, lft1, lft2);
            
            %Check proper vertical concatenation
            verifyEqual(testCase, diag_lft.a, a_out);
            verifyEqual(testCase, diag_lft.b, b_out);
            verifyEqual(testCase, diag_lft.c, c_out);
            verifyEqual(testCase, diag_lft.d, d_out);
            verifyEqual(testCase, diag_lft.delta.deltas, deltas_out.deltas);
        end
        
        function testUlftBlkdiagOutputRandom(testCase)
            n = 10;
            for i = 1:n
                dim_in = randi([1, 10]);
                dim_out = randi([1, 10]);
                if i < n/2
                    req_deltas = {'DeltaDelayZ'};
                else
                    req_deltas = {'DeltaIntegrator'};
                end
                
                lft_array = cell(1, 2);
                for n = 1:length(lft_array)
                    lft_array{n} = Ulft.random('dim_in', dim_in,...
                                               'dim_out', dim_out,...
                                               'req_deltas', req_deltas);
                end
                
                if mod(i, 2)
                    lft_array{1} = removeUncertainty(lft_array{1}, 1);
                end
                
                lft_array{2} = removeUncertainty(lft_array{2}, 1);
                result_lft = blkdiag(lft_array{1}, lft_array{2});
                result_horizon = result_lft.horizon_period;
                lft_array{1} = matchHorizonPeriod(lft_array{1},...
                                                  result_horizon);
                lft_array{2} = matchHorizonPeriod(lft_array{2},...
                                                  result_horizon);
                output_delta = result_lft.delta.deltas;
                correct_delta = SequenceDelta(lft_array{1}.delta.deltas,...
                                              lft_array{2}.delta.deltas);
                verifyEqual(testCase, output_delta, correct_delta.deltas)
                        
               %Check proper vertical concatenation
                for t = 1:sum(result_lft.horizon_period)
                    verifyEqual(testCase,...
                                result_lft.a{t},...
                                blkdiag(lft_array{1}.a{t}, lft_array{2}.a{t}));
                    verifyEqual(testCase,...
                                result_lft.b{t},...
                                blkdiag(lft_array{1}.b{t}, lft_array{2}.b{t}));
                    verifyEqual(testCase,...
                                result_lft.c{t},...
                                blkdiag(lft_array{1}.c{t}, lft_array{2}.c{t}));
                    verifyEqual(testCase,...
                                result_lft.d{t},...
                                blkdiag(lft_array{1}.d{t}, lft_array{2}.d{t}));
                end
            end
            
            
        end
    
        %Check performance on higher number of LFTs
        function testUlftBlkdiagDeltaZRepeat(testCase)
            temp_a = cell(1, 5);
            temp_b = cell(1, 5);
            temp_c = cell(1, 5);
            temp_d = cell(1, 5);
            for i = 1:5
                temp_a{i} = i*ones(4, 4);
                temp_b{i} = i*ones(4, 1);
                temp_c{i} = i*ones(1, 4);
                temp_d{i} = i;
            end
            
            [a1, a2, a3, a4, a5] = deal(temp_a{1}, temp_a{2}, temp_a{3},...
                                        temp_a{4}, temp_a{5});
            [b1, b2, b3, b4, b5] = deal(temp_b{1}, temp_b{2}, temp_b{3},...
                                        temp_b{4}, temp_b{5});
            [c1, c2, c3, c4, c5] = deal(temp_c{1}, temp_c{2}, temp_c{3},...
                                        temp_c{4}, temp_c{5});
            [d1, d2, d3, d4, d5] = deal(temp_d{1}, temp_d{2}, temp_d{3},...
                                        temp_d{4}, temp_d{5});
            delta1 = DeltaDelayZ(4);
            delta2 = DeltaDelayZ(4);
            delta3 = DeltaBounded('d', 4, 4);
            delta4 = DeltaSlti('c', 4);
            delta5 = DeltaSltv('e', 4);
            
            lft1 = Ulft(a1, b1, c1, d1, delta1);
            lft2 = Ulft(a2, b2, c2, d2, delta2);
            lft3 = Ulft(a3, b3, c3, d3, delta3);
            lft4 = Ulft(a4, b4, c4, d4, delta4);
            lft5 = Ulft(a5, b5, c5, d5, delta5);
            
            a_out = {blkdiag(a1, a2, a3, a4, a5)};
            b_out = {blkdiag(b1, b2, b3, b4, b5)};
            c_out = {blkdiag(c1, c2, c3, c4, c5)};
            d_out = {blkdiag(d1, d2, d3, d4, d5)};
            %Concatenate deltas together
            delta_sum = DeltaDelayZ(8);
            deltas_out = SequenceDelta(delta_sum, delta3, delta4, delta5);
            diag_lft = blkdiag(lft1, lft2, lft3, lft4, lft5);
            
            %Check proper vertical concatenation
            verifyEqual(testCase, diag_lft.a, a_out);
            verifyEqual(testCase, diag_lft.b, b_out);
            verifyEqual(testCase, diag_lft.c, c_out);
            verifyEqual(testCase, diag_lft.d, d_out);
            verifyEqual(testCase, diag_lft.delta.deltas, deltas_out.deltas);
        end
        
        function testUlftBlkdiagRepetition(testCase)
            a1 = reshape([1:16], 4, 4);
            a2 = ones(4, 4);
            b1 = [1:4]';
            b2 = [5:8]';
            c1 = [1:4];
            c2 = [5:8];
            d1 = 0;
            d2 = 0;
            delta1 = DeltaSlti('a', 4);
            delta2 = DeltaSlti('a', 4);
            % Generate repeated performance/disturbances to verify
            % duplicates not repeated
            performance1 = PerformanceL2Induced('a');
            disturbance1 = DisturbanceL2('a');
            lft1 = Ulft(a1, b1, c1, d1, delta1,...
                        'performance', performance1,...
                        'disturbance', disturbance1);
            lft2 = Ulft(a2, b2, c2, d2, delta2,...
                        'performance', performance1,...
                        'disturbance', disturbance1);
            a_out = {blkdiag(a1, a2)};
            b_out = {blkdiag(b1, b2)};
            c_out = {blkdiag(c1, c2)};
            d_out = {blkdiag(d1, d2)};
            delta_out = DeltaSlti('a', 8);
            disturbance_out = SequenceDisturbance(DisturbanceL2('a', {[]}));

            diag_lft = blkdiag(lft1, lft2);
            
            verifyEqual(testCase, diag_lft.delta.deltas, {delta_out});
            verifyEqual(testCase, diag_lft.disturbance, disturbance_out);
            verifyEqual(testCase, diag_lft.performance, lft1.performance);
            
        end
        
        function testUlftBlkdiagPerformance(testCase)
        % Tests if blkdiag is appropriately adjusting channels for performance
            a1 = reshape([1:16], 4, 4);
            a2 = ones(4, 4);
            b1 = [1:4]';
            b2 = [5:8]';
            c1 = [1:4];
            c2 = [5:8];
            d1 = 0;
            d2 = 0;
            delta1 = DeltaSlti('a', 4);
            delta2 = DeltaSlti('a', 4);
            % The blkdiagted performance should pertain to all
            % input-output-channels (flagged with an empty element in cell
            % array)
            performance1 = PerformanceL2Induced('a', {}, {});
            disturbance1 = DisturbanceL2('a');
            lft1 = Ulft(a1, b1, c1, d1, delta1,...
                        'performance', performance1,...
                        'disturbance', disturbance1);
            lft2 = Ulft(a2, b2, c2, d2, delta2,...
                        'performance', performance1,...
                        'disturbance', disturbance1);

            diag_lft = blkdiag(lft1, lft2);
            output_performance = SequencePerformance(performance1);
            output_disturbance = ...
                SequenceDisturbance(DisturbanceL2('a', {[]}));
            verifyEqual(testCase, diag_lft.performance, output_performance);
            verifyEqual(testCase, diag_lft.disturbance, output_disturbance);
            
            % The blkdiagted performance should pertain to the [1] input
            % channel and [1, 2] output channel        
            performance1 = PerformanceL2Induced('a', {1}, {1});
            disturbance1 = DisturbanceL2('a', {1});
            lft1 = Ulft(a1, b1, c1, d1, delta1,...
                        'performance', performance1,...
                        'disturbance', disturbance1);
            lft2 = Ulft(a2, b2, c2, d2, delta2,...
                        'performance', performance1,...
                        'disturbance', disturbance1);
            diag_lft = blkdiag(lft1, lft2);
            output_performance = ...
                SequencePerformance(PerformanceL2Induced('a', {[1;2]},{[1;2]}));
            output_disturbance = ...
                SequenceDisturbance(DisturbanceL2('a', {[1;2]}));
            verifyEqual(testCase, diag_lft.performance, output_performance);
            verifyEqual(testCase, diag_lft.disturbance, output_disturbance);
            
            % Similar check without any perf/dist for first lft
            lft1 = lft1.removeDisturbance({'a'}).removePerformance({'a'});
            diag_lft = blkdiag(lft1, lft2);
            output_performance = ...
                SequencePerformance(PerformanceL2Induced('a', {2},{2}));
            output_disturbance = ...
                SequenceDisturbance(DisturbanceL2('a', {2}));
            verifyEqual(testCase, diag_lft.performance, output_performance);
            verifyEqual(testCase, diag_lft.disturbance, output_disturbance);
        end
        
        function testUlftBlkdiagHorizonChecking(testCase)
            temp_a = cell(2, 3);
            temp_b = cell(2, 3);
            temp_c = cell(2, 3);
            temp_d = cell(2, 3);
            for j = 1:2
                for i = 1:3
                    temp_a{j, i} = (10*j + i)*ones(4, 4);
                    temp_b{j, i} = (10*j + i)*ones(4, 1);
                    temp_c{j, i} = (10*j + i)*ones(1, 4);
                    temp_d{j, i} = (10*j + i);
                end
            end
            [a1, a2, a3] = deal(temp_a(:, 1)', temp_a(:, 2)', temp_a(:, 3)');
            [b1, b2, b3] = deal(temp_b(:, 1)', temp_b(:, 2)', temp_b(:, 3)');
            [c1, c2, c3] = deal(temp_c(:, 1)', temp_c(:, 2)', temp_c(:, 3)');
            [d1, d2, d3] = deal(temp_d(:, 1)', temp_d(:, 2)', temp_d(:, 3)');
            delta1 = DeltaDelayZ(4);
            delta2 = DeltaDelayZ(4);
            delta3 = DeltaBounded('c', 4, 4);
            delta4 = DeltaSlti('d', 4);
            delta5 = DeltaSltv('e', 4);
            
            horizon1 = [1, 1];
            horizon2 = [0, 2];
            horizon3 = [1, 1];

            lft1 = Ulft(a1, b1, c1, d1, delta1,...
                        'horizon_period', horizon1);
            lft2 = Ulft(a2, b2, c2, d2, delta3,...
                        'horizon_period', horizon2);
            lft3 = Ulft(a3, b3, c3, d3, delta5,...
                        'horizon_period', horizon3);

            diag_lft = blkdiag(lft1, lft2, lft3);
            verifyEqual(testCase, diag_lft.horizon_period, [1 2]);
            
            %Expected output mapping based on the given horizon periods
            expected_output_map = {[1, 1, 1], [2, 2, 2], [2, 1, 2]};
            for t = 1:sum(diag_lft.horizon_period)
                time_map = expected_output_map{t};
                output_a = blkdiag(a1{time_map(1)}, a2{time_map(2)},...
                                   a3{time_map(3)});
                output_b = blkdiag(b1{time_map(1)}, b2{time_map(2)},...
                                   b3{time_map(3)});
                output_c = blkdiag(c1{time_map(1)}, c2{time_map(2)},...
                                   c3{time_map(3)});
                output_d = blkdiag(d1{time_map(1)}, d2{time_map(2)},...
                                   d3{time_map(3)});
                
                verifyEqual(testCase, diag_lft.a{t}, output_a);
                verifyEqual(testCase, diag_lft.b{t}, output_b);
                verifyEqual(testCase, diag_lft.c{t}, output_c);
                verifyEqual(testCase, diag_lft.d{t}, output_d);
            end
        end
        
        function testBlkdiagReorder(testCase)
            a_grp = cell(1, 9);
            b_grp = cell(1, 9);
            c_grp = cell(1, 9);
            d_grp = cell(1, 9);

            for LFT_num = 1:9
                a_grp{LFT_num} = LFT_num*ones(4, 4);%{reshape([(16*i-15:16*i)], 4, 4)};
                b_grp{LFT_num} = LFT_num*ones(4, 1);%{[4*i-3:4*i]'};
                c_grp{LFT_num} = LFT_num*ones(1, 4);%{[4*i-3:4*i]};
                d_grp{LFT_num} = LFT_num;
            end
            
            delta1 = DeltaSlti('a', 4);
            delta2 = DeltaSlti('b', 4);
            delta3 = DeltaBounded('c', 4, 4);
            delta4 = DeltaDelayZ(4);
            delta5 = DeltaSltv('e', 4);
            
            lft_cell = cell(1, 9);
            lft_cell{1} = Ulft(a_grp{1}, b_grp{1}, c_grp{1}, d_grp{1},...
                               delta1);
            lft_cell{2} = Ulft(a_grp{2}, b_grp{2}, c_grp{2}, d_grp{2},...
                               delta2);
            lft_cell{3} = Ulft(a_grp{3}, b_grp{3}, c_grp{3}, d_grp{3},...
                               delta3);
            lft_cell{4} = Ulft(a_grp{4}, b_grp{4}, c_grp{4}, d_grp{4},...
                               delta4);
            lft_cell{5} = Ulft(a_grp{5}, b_grp{5}, c_grp{5}, d_grp{5},...
                               delta5);
            lft_cell{6} = Ulft(a_grp{6}, b_grp{6}, c_grp{6}, d_grp{6},...
                               delta1);
            lft_cell{7} = Ulft(a_grp{7}, b_grp{7}, c_grp{7}, d_grp{7},...
                               delta2);
            lft_cell{8} = Ulft(a_grp{8}, b_grp{8}, c_grp{8}, d_grp{8},...
                               delta3);
            lft_cell{9} = Ulft(a_grp{9}, b_grp{9}, c_grp{9}, d_grp{9},...
                               delta4);
            lft_order = [1, 3, 2, 4, 5, 6, 7, 8, 9];
            
            lft_to_concat = lft_cell(lft_order);
            diag_lft = blkdiag(lft_to_concat{:});
            
            delta1_out = DeltaSlti('a', 8);
            delta2_out = DeltaSlti('b', 8);
            delta3_out = DeltaBounded('c', 8, 8);
            delta4_out = DeltaDelayZ(8);
            
            % Expected order of grouped, reorded outputs
            grouped_order_map = [4, 9, 1, 6, 2, 8, 3, 7, 5];
            % Reordering grouped lfts to match lft input order
            a_reorder = a_grp(lft_order);
            b_reorder = b_grp(lft_order);
            c_reorder = c_grp(lft_order);
            d_reorder = d_grp(lft_order);
            % Reordering a, b matrices to match expected output order
            a_reorder = a_reorder(grouped_order_map);
            % Builds expected output matrix in the proper order from ^^
            a_out = {blkdiag(a_reorder{:})};
            % Note, this is not a cell matrix because we need to do some
            % manipulations in how we move it into the cell paradigm to
            % ensure proper order
            b_out = blkdiag(b_reorder{:});
            c_out = blkdiag(c_reorder{:});
            d_out = {blkdiag(d_reorder{:})};
            %Reordering b and c to match the reordered b and c matrix
            b_out_cell = mat2cell(b_out, [4, 4, 4, 4, 4, 4, 4, 4, 4], 9);
            b_out_cell = b_out_cell(grouped_order_map);
            c_out_cell = mat2cell(c_out, 9, [4, 4, 4, 4, 4, 4, 4, 4, 4]);
            c_out_cell = c_out_cell(grouped_order_map);
            %Rebuilding b and c matrix
            b_out = {cell2mat(b_out_cell)};
            c_out = {cell2mat(c_out_cell)};
            delta_out = SequenceDelta(delta4_out, delta1_out,...
                                      delta3_out, delta2_out, delta5);
                                  
            verifyEqual(testCase, diag_lft.a, a_out);
            verifyEqual(testCase, diag_lft.b, b_out);
            verifyEqual(testCase, diag_lft.c, c_out);
            verifyEqual(testCase, diag_lft.d, d_out);
            verifyEqual(testCase, diag_lft.delta.deltas, delta_out.deltas);
        end
        
        function testUlftBlkdiagValidInput(testCase)
            % This test generates valid non-LFT objects to blkdiag with a
            % valid LFT
            temp_a = cell(1, 2);
            temp_b = cell(1, 2);
            temp_c = cell(1, 2);
            temp_d = cell(1, 2);
            for i = 1:2
                temp_a{i} = reshape([(16*i-15:16*i)], 4, 4);
                temp_b{i} = [4*i-3:4*i]';
                temp_c{i} = [4*i-3:4*i];
                temp_d{i} = 0;
            end
            b3 = 2*ones(4, 4);
            d3 = 2*ones(4, 4);
            c3 = 2*ones(4, 4);
            
            [a1, a2] = deal(temp_a{1}, temp_a{2});
            [b1, b2] = deal(temp_b{1}, temp_b{2});
            [c1, c2] = deal(temp_c{1}, temp_c{2});
            [d1, d2] = deal(temp_d{1}, temp_d{2});
            delta1 = DeltaSlti('a', 4);
            delta2 = DeltaSlti('b', 4);
            ss_model = ss(a2, b2, c2, d2);
            ss_delta = DeltaIntegrator(4);

            lft1 = Ulft(a1, b1, c1, d1, delta1);
            lft2 = Ulft(a1, b3, c3, d3, delta1);
            
            % Expected value of blkdiag(double, LFT). blkdiag with a double
            % blkdiags it to the d matrix, nothing else. zeroes must
            % therefore be appended to the c matrix
            double_input = 5;
            double_b = [zeros(4, 1), b1];
            double_c = [zeros(1, 4); c1];
            double_d = blkdiag(double_input, d1);
            double_lft_output = Ulft(a1, double_b, double_c, double_d, delta1);
            double_lft_result = blkdiag(double_input, lft1);
            verifyEqual(testCase, double_lft_result, double_lft_output);

            % Expected value of blkdiag([double], LFT). blkdiag treats an
            % array of doubles the same way as a double, with added
            % dimensions
            double_array_input = [3; 5];
            array_b = [zeros(4, 1), b1];
            array_c = [zeros(2, 4); c1];
            array_d = blkdiag(double_array_input, d1);
            double_array_output = Ulft(a1, array_b, array_c, array_d, delta1);
            double_array_lft_result = blkdiag(double_array_input, lft1);
            verifyEqual(testCase, double_array_lft_result, double_array_output);

            
            % Expected value of blkdiag(delta, LFT). blkdiag generates a
            % nxn lft from the delta, where n is the input_dim of the
            % delta. This LFT has zeros(n,n) for a,d, I(n) for b,c
            delta_out = delta2 + delta1;
            a_delta_output = blkdiag(zeros(4, 4), a1);
            b_delta_output = blkdiag(eye(4), b3);
            c_delta_output = blkdiag(eye(4), c3);
            d_delta_output = blkdiag(zeros(4, 4), d3);
            delta_lft_output = Ulft(a_delta_output, b_delta_output,...
                                    c_delta_output, d_delta_output,...
                                    delta_out.delta);
            delta_lft_result = blkdiag(delta2, lft2);
            verifyEqual(testCase, delta_lft_result, delta_lft_output);

            
            % Expected value of blkdiag(ss, LFT). blkdiag generates a LFT
            % from the steady-state object and creates a geneator for the
            % delta
            delta_out_ss = SequenceDelta(ss_delta, delta1);
            ss_lft_output = Ulft(blkdiag(a2, a1), blkdiag(b2, b1),...
                                 blkdiag(c2, c1), blkdiag(d2, d1), delta_out_ss);

            ss_lft_result = blkdiag(ss_model, lft1);
            verifyEqual(testCase, ss_lft_result, ss_lft_output);
            
            % Verify that blkdiag() throws error when given invalid non-LFT
            % input           
            verifyError(testCase, @() blkdiag('hi', lft1), ?MException);

        end
    end

end

%%  CHANGELOG
% Sep. 28, 2021 (v0.6.0)
% Aug. 26, 2021 (v.0.5.0): Initial release - Micah Fry (micah.fry@ll.mit.edu)
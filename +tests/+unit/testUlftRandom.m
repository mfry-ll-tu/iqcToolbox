%% Requirements:
%  1. Ulft.random shall be capable of randomly generating a Ulft object by randomly generating:
%      - Any number of allowable Delta objects in the Ulft
%      - Any type of Delta objects in the Ulft
%      - The horizon_period of the Ulft
%      - The input/output size of the Ulft
%      Note: Allowable Delta objects are currently DeltaIntegrator, DeltaDelayZ,
%      DeltaSlti, DeltaDlti, DeltaBounded, DeltaSltv, DeltaSltvRateBnd, and DeltaSltvRepeated 
%  2. Ulft.random shall randomly determine if the Ulft object is continuous-time, discrete-time, or memoryless. 
%      If continuous-time, the output Ulft object shall have a horizon_period of [0, 1].
%  3. Ulft.random shall allow users to constrain the input/output dimensions of the output Ulft object.
%  4. Ulft.random shall allow users to specify the number of Delta objects in the output Ulft object.
%  5. Ulft.random shall allow users to provide specific Delta classes (and the multiplicity 
%      of objects from that class) that must appear in the output Ulft object.
%  6. Ulft.random shall allow users to provide specific Delta objects that must appear in the output Ulft object.
%  7. Ulft.random shall ensure that the output Ulft object is nominally stable
%  8. Ulft.random shall throw an error if the user inputs will not produce a horizon_period consistent with those inputs.

%%
%  Copyright (c) 2021 Massachusetts Institute of Technology 
%  SPDX-License-Identifier: GPL-2.0
%%

%% Test class for Ulft.
classdef testUlftRandom < matlab.unittest.TestCase
properties 
    del_not_states = {'DeltaBounded', 'DeltaDlti',         'DeltaSlti',...
                      'DeltaSltv',    'DeltaSltvRateBnd'};
end

methods (TestMethodSetup)
    function seedAndReportRng(testCase)
    seed = floor(posixtime(datetime('now')));
    rng(seed, 'twister');
    diagnose_str = ...
        sprintf(['Random inputs may be regenerated by calling: \n',...
                 '>> rng(%10d) \n',...
                 'before running the remainder of the test''s body'],...
                seed);
    testCase.onFailure(@() fprintf(diagnose_str));
    end    
end

methods (Test)
function testSpecificUseCases(testCase) 
% Can have discrete time and hp = [0, 1]
hp = [0, 1];
time_delta = DeltaDelayZ();
lft = Ulft.random('horizon_period', hp, 'req_deltas', {time_delta});
verifyEqual(testCase, lft.horizon_period, hp)

% Can have continuous time and hp = [0, 1]
hp = [0, 1];
time_delta = DeltaIntegrator(6);
lft = Ulft.random('horizon_period', hp, 'req_deltas', {time_delta});
verifyEqual(testCase, lft.horizon_period, hp)
end

function testRandomGeneration(testCase)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Set up a number of runs of Ulft.random()
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
sample_size = 5000;
number_of_deltas = nan(1, sample_size);
type_of_deltas = cell(1, sample_size);
horizon_of_lfts = nan(1, sample_size);
period_of_lfts = nan(1, sample_size);
dim_out_of_lfts = nan(1, sample_size);
dim_in_of_lfts = nan(1, sample_size);
size_is_constant = nan(1, sample_size);
for i = 1:sample_size
    lft = Ulft.random();
    number_of_deltas(i) = length(lft.delta.names);
    type_of_deltas{i} = lft.delta.types;
    horizon_of_lfts(i) = lft.horizon_period(1);
    period_of_lfts(i) = lft.horizon_period(2);
    [dim_out, dim_in] = size(lft);
    if all(dim_out(1) == dim_out, 'all') ...
       && all(dim_in(1) == dim_in, 'all')
        size_is_constant(i) = true;
        dim_out_of_lfts(i) = dim_out(1);
        dim_in_of_lfts(i) = dim_in(1);
    else
        size_is_constant(i) = false;
    end
end
list_of_types = horzcat(type_of_deltas{:});
is_state = strcmp(list_of_types, 'DeltaDelayZ') ...
           | strcmp(list_of_types, 'DeltaIntegrator');
types_states = list_of_types;
types_states(~is_state) = [];
types_not_states = list_of_types;
types_not_states(is_state) = [];

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Verify that various Ulft properties appear in significant numbers
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
threshold = 0.65;

verifyThreshld = @(batch, elements, sample_size) ...
    tests.unit.testUlftRandom.verifyThreshold(batch, elements, threshold, sample_size, testCase);

% Good sampling of number of deltas
elements_number = 0:max(number_of_deltas);
verifyThreshld(number_of_deltas, elements_number, sample_size)

% Good sampling of dim_outs
elements_dim_out = 1:max(dim_out_of_lfts);
verifyThreshld(dim_out_of_lfts, elements_dim_out, sample_size)

% Good sampling of dim_ins
elements_dim_in = 1:max(dim_in_of_lfts);
verifyThreshld(dim_in_of_lfts, elements_dim_in, sample_size)

% Good sampling of states
elements_states = {'DeltaDelayZ', 'DeltaIntegrator'}; 
verifyThreshld(types_states, elements_states, 2 * sample_size / 3)

% Good sampling of nonstates
verifyGreaterThan(testCase,...
                  sample_size - length(types_states),...
                  threshold * sample_size / 3)

elements_nonstates = testCase.del_not_states;
verifyThreshld(types_not_states, elements_nonstates, length(types_not_states))

% Good sampling of LTI
num_of_lti = sum(horizon_of_lfts == 0 & period_of_lfts == 1);
verifyGreaterThan(testCase, num_of_lti, threshold * 2 * sample_size / 3)

% Good sampling of horizons
elements_horizon = 0:max(horizon_of_lfts);
verifyThreshld(horizon_of_lfts, elements_horizon, sample_size / 3)

% Good sampling of periods
elements_period = 1:max(period_of_lfts);
verifyThreshld(period_of_lfts, elements_period, sample_size / 3)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Gather data on all the runs (for introspection, call summary(c_type_of_deltas) )
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% c_type_of_deltas = categorical(horzcat(type_of_deltas{:}));
% c_number_of_deltas = categorical(number_of_deltas);
% c_dim_out_of_lfts = categorical(dim_out_of_lfts);
% c_dim_in_of_lfts = categorical(dim_in_of_lfts);
% c_horizon_of_lfts = categorical(horizon_of_lfts);
% c_period_of_lfts = categorical(period_of_lfts);
% c_size_is_constant = categorical(size_is_constant);
% c_types_states = removecats(c_type_of_deltas, {'DeltaBounded', 'DeltaDlti', 'DeltaSlti', 'DeltaSltv', 'DeltaSltvRateBnd'});
% c_types_states(isundefined(c_types_states)) = [];
% c_types_nonstates = removecats(c_type_of_deltas, {'DeltaDelayZ', 'DeltaIntegrator'});
% c_types_nonstates(isundefined(c_types_nonstates)) = [];
end

function testContinuousImpliesTimeInvariant(testCase)
sample_size = 100;

verifyContinuousLti = @(generator, args) ...
    tests.unit.testUlftRandom.verifyContinuousImpliesLti(generator(args{:}),...
                                                         sample_size,...
                                                         testCase);

% Test that continuous implies lti for various pertinent input arguments
verifyContinuousLti(@Ulft.random, {})
verifyContinuousLti(@Ulft.random, {'req_deltas', {'DeltaIntegrator'}})
verifyContinuousLti(@Ulft.random,...
                    {'req_deltas', {DeltaIntegrator(randi([1, 10]))}})

% Test that not lti implies not continuous
not_lti_implies_not_continuous = true;
for i = 1:sample_size
    lft = Ulft.random('horizon_period', [randi([1, 10]), randi([2, 10])]);
    if any(strcmp(lft.delta.types, 'DeltaIntegrator'))
        not_lti_implies_not_continuous = false;
        break
    end
end
verifyTrue(testCase, not_lti_implies_not_continuous)
end

function testConstrainLftSize(testCase)
sample_size = 100;
correct_size = true;
for i = 1:sample_size
    dim_out = randi([1, 10]);
    dim_in  = randi([1, 10]);
    lft = Ulft.random('dim_out', dim_out, 'dim_in', dim_in);
    [dim_out_lft, dim_in_lft] = size(lft);
    assertTrue(testCase, all(dim_out_lft(1) == dim_out_lft))
    assertTrue(testCase, all(dim_in_lft(1) == dim_in_lft))
    if ~(dim_out == dim_out_lft(1) && dim_in == dim_in_lft(1))
        correct_size = false;
        break
    end
end
verifyTrue(testCase, correct_size)
end

function testConstrainDeltaNumber(testCase)
sample_size = 100;

% Only with Delta number as argument
correct_number = true;
for i = 1:sample_size
    num_deltas = randi([0, 10]);
    lft = Ulft.random('num_deltas', num_deltas);
    if length(lft.delta.deltas) ~= num_deltas
        correct_number = false;
        break
    end
end
verifyTrue(testCase, correct_number)

% Along with Delta types as argument
correct_number = true;
types = testCase.del_not_states;
for i = 1:sample_size
    num_deltas = randi([0, 10]);
    req_deltas = cell(1, randi([1, length(types)]));
    for j = 1:length(req_deltas)
        req_deltas{j} = types{randi([1, length(types)])};
    end
    lft = Ulft.random('num_deltas', num_deltas, 'req_deltas', req_deltas);
    if length(lft.delta.deltas) ~= max(num_deltas, length(req_deltas))
        correct_number = false;
        break
    end
end
verifyTrue(testCase, correct_number)

% Along with specific Deltas as argument
correct_number = true;
for i = 1:sample_size
    num_deltas = randi([0, 20]);
    lft_temp = Ulft.random();
    spec_deltas = lft_temp.delta.deltas;
    type_deltas = cell(1, randi([1, length(types)]));
    for j = 1:length(type_deltas)
        type_deltas{j} = types{randi([1, length(types)])};
    end
    req_deltas = [type_deltas, spec_deltas];
    lft = Ulft.random('num_deltas', num_deltas, 'req_deltas', req_deltas);
    if length(lft.delta.deltas) ~= max(num_deltas, length(req_deltas))
        correct_number = false;
        break
    end
end
verifyTrue(testCase, correct_number)
end

function testConstrainDeltaTypes(testCase)
sample_size = 100;
types = testCase.del_not_states;
state_seed = {'DeltaDelayZ', 'DeltaIntegrator', 'DeltaBounded'};
correct_types = true;
for i = 1:sample_size
    req_type = cell(1, randi([1, length(types)]));
    for j = 1:length(req_type)
        req_type{j} = types{randi([1, length(types)])};
    end
    state_type = state_seed{randi([1, 3])};
    req_deltas = [req_type, state_type];
    lft = Ulft.random('req_deltas', req_deltas);
    delta_types = lft.delta.types;
    for j = 1:length(req_deltas)
        match_inds = strcmp(req_deltas{j}, delta_types);
        if any(match_inds)
            delta_types(find(match_inds, 1, 'first')) = [];
        else
            correct_types = false;
            break
        end
    end
    if ~correct_types
        break
    end
end
verifyTrue(testCase, correct_types)
end

function testConstrainDeltaSpecifics(testCase)
sample_size = 100;
correct_deltas = true;
for i = 1:sample_size
    lft_temp = Ulft.random();
    req_deltas = lft_temp.delta.deltas;
    lft = Ulft.random('req_deltas', req_deltas);
    deltas = lft.delta.deltas;
    for j = 1:length(req_deltas)
        match_found = false;
        for k = 1:length(deltas)
            if isequal(req_deltas{j}, deltas{k})
                deltas{k} = [];
                match_found = true;
            end
        end
        if ~match_found
            correct_deltas = false;
            break
        end
    end
    if ~correct_deltas
        break
    end
end
verifyTrue(testCase, correct_deltas)
end

function testNominalStability(testCase)

% Discrete-time (possibly LTV) tests
sample_size = 10;
opts = AnalysisOptions('lmi_shift', 1e-6, 'verbose', false);
nominally_stable = true;
for i = 1:sample_size
    del_time = DeltaDelayZ(randi([1, 10]));
    lft = Ulft.random('req_deltas', {del_time});
    lft_nominal = removeUncertainty(lft, [2:length(lft.delta.names)]);
    result = iqcAnalysis(lft_nominal, 'analysis_options', opts);
    if ~result.valid
        nominally_stable = false;
        break
    end
end
verifyTrue(testCase, nominally_stable)

% Continuous-time (always LTI) tests
sample_size = 1000;
nominally_stable = true;
for i = 1:sample_size
    del_time = DeltaIntegrator(randi([1, 10]));
    lft = Ulft.random('req_deltas', {del_time});
    lft_nominal = removeUncertainty(lft, [2:length(lft.delta.names)]);
    if max(real(eig(lft_nominal.a{1}))) >= 0
        nominally_stable = false;
        break
    end
end
verifyTrue(testCase, nominally_stable)
end

function testInconsistentHorizonPeriod(testCase)
% Breaks if given Deltas can't conform to lft horizon_period
hp_lft = [3, 5];
hp_delta = [3, 7];
del = DeltaSltv('t', 1, -1, 1,hp_delta);
verifyError(testCase,...
            @() Ulft.random('horizon_period', hp_lft, 'req_deltas', {del}),...
            ?MException)
verifyError(testCase,...
            @() Ulft.random('horizon_period', hp_lft,...
                            'req_deltas', {del},...
                            'num_deltas', 5),...
            ?MException)

hp_delta = [5, 5];
del = DeltaSltv('t', 1, -1, 1,hp_delta);
verifyError(testCase,...
            @() Ulft.random('horizon_period', hp_lft, 'req_deltas', {del}),...
            ?MException)
verifyError(testCase,...
            @() Ulft.random('horizon_period', hp_lft,...
                            'req_deltas', {del},...
                            'num_deltas', 5),...
            ?MException)

hp_delta = [5, 7];
del = DeltaSltv('t', 1, -1, 1,hp_delta);
verifyError(testCase,...
            @() Ulft.random('horizon_period', hp_lft, 'req_deltas', {del}),...
            ?MException)
verifyError(testCase,...
            @() Ulft.random('horizon_period', hp_lft,...
                            'req_deltas', {del},...
                            'num_deltas', 5),...
            ?MException)

% Works if given Delta can conform to lft horizon_period
hp_lft = [2, 3];
hp_delta = [1, 1];
del = DeltaBounded('t', 1, 1, 1, hp_delta);
lft = Ulft.random('horizon_period', hp_lft, ...
                  'req_deltas', {del},...
                  'num_deltas', 6);
verifyEqual(testCase, lft.horizon_period, hp_lft)
verifyEqual(testCase, lft.delta.horizon_periods(1, :), hp_lft)

% Breaks if Continuous-time w/ bad horizon_period
del = DeltaIntegrator();
hp = [randi([1, 10]), 1];
verifyError(testCase,...
            @() Ulft.random('horizon_period', hp, 'req_deltas', {del}),...
            ?MException)
hp = [0, randi([2, 10])];
verifyError(testCase,...
            @() Ulft.random('horizon_period', hp, 'req_deltas', {del}),...
            ?MException)
hp = [randi([1, 10]), randi([2, 10])];
verifyError(testCase,...
            @() Ulft.random('horizon_period', hp, 'req_deltas', {del}),...
            ?MException)

% Works if Continuous-time w/ good horizon_period
del = DeltaIntegrator;
hp = [0, 1];
lft = Ulft.random('horizon_period', hp, 'req_deltas', {del});
verifyEqual(testCase, lft.horizon_period, hp)
verifyEqual(testCase, lft.delta.deltas{1}, del)
end

function testBadTypeRequest(testCase)
verifyError(testCase,...
            @() Ulft.random('req_deltas', {'ImpermissibleDelta'}),...
            ?MException)
end

end % methods (Test)

methods (Static)
function verifyThreshold(batch, elements, threshold, total, testCase)
    num_elements = length(elements);
    expected = total / num_elements * threshold;
    each_element_appears_enough = true;
    for i = 1:num_elements
        if iscell(batch)
            num_with_element = sum(strcmp(batch, elements(i)));
        else
            num_with_element = sum(batch == elements(i));
        end
        if num_with_element < expected
            each_element_appears_enough = false;
            break;
        end
    end
    verifyTrue(testCase, each_element_appears_enough)
end

function verifyContinuousImpliesLti(lft_generator, sample_size, testCase)
    continuous_implies_lti = true;
    for i = 1:sample_size
        lft = lft_generator;
        if any(strcmp(lft.delta.types, 'DeltaIntegrator'), 'all')
            if ~isequal(lft.horizon_period, [0, 1])
                continuous_implies_lti = false;
                break
            end
        end
    end
    verifyTrue(testCase, continuous_implies_lti)
end
end
end

%%  CHANGELOG
% Sep. 28, 2021 (v0.6.0)
% Aug. 26, 2021 (v.0.5.0): Initial release - Micah Fry (micah.fry@ll.mit.edu)
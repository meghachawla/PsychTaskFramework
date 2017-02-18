function [ Data ] = SODM(observer)
% SODM Runs a self-other monetary and medical decision-making task and records
%   its results for the participant whose subject number is passed in. Modeled
%   on (and largely copy-pasted from) RA.m, to test out image implementation
%   (#5).

%% Add subfolders we'll be using to path
addpath(genpath('./lib'));
addpath(genpath('./tasks/SODM'));
% NOTE: genpath gets the directory and all its subdirectories

%% Load settings
settings = SODM_config();

%% Setup
KbName(settings.device.KbName);
s = RandStream.create('mt19937ar', 'seed', sum(100*clock));
RandStream.setGlobalStream(s);

if exist('observer', 'var') % Running actual trials -> record
  % Find-or-create participant data file *in appropriate location*
  fname = [num2str(observer) '.mat'];
  folder = fullfile(settings.device.taskPath, 'data');
  fname = [folder filesep fname];
  [ Data, participantExisted ] = loadOrCreate(observer, fname);

  % TODO: Prompt experimenter if this is correct
  if participantExisted
    disp('Participant file exists, reusing...')
  else
    disp('Participant has no file, creating...')
    Data.date = datestr(now, 'yyyymmddTHHMMSS');
  end

  % Save participant ID + date
  % TODO: Prompt for correctness before launching PTB?
  Data.observer = observer;
  Data.lastAccess = datestr(now, 'yyyymmddTHHMMSS');
  if mod(observer, 2) == 0
      settings.perUser.refSide = 1;
  else
      settings.perUser.refSide = 2;
  end
else % Running practice
  Data.observer = 1;
  settings.perUser.refSide = randi(2);
  settings.device.saveAfterBlock = false;
end

% Open window
[settings.device.windowPtr, settings.device.screenDims] = ...
  Screen('OpenWindow', settings.device.screenId, ...
  settings.default.bgrColor);
% Disambiguate settings here
monSettings = SODM_config_monetary(settings);
medSettings = SODM_config_medical(settings);
medSettings.textures = loadTexturesFromConfig(medSettings);

%% Generate trials if not generated already
if ~isfield(Data, 'blocks') || ~isfield(Data.blocks, 'planned')
  medBlocks = generateBlocks(medSettings);
  monBlocks = generateBlocks(monSettings);

  sortOrder = mod(Data.observer, 4);
  selfIdx = [1 0 1 0];
  medIdx = [1 1 0 0];

  switch sortOrder
    case 0
      % Keep order
    case 1
      selfIdx = 1 - selfIdx;
    case 2
      medIdx = 1 - medIdx;
    case 3
      selfIdx = 1 - selfIdx;
      medIdx = 1 - medIdx;
  end

  % Logic: Do two mon/med block(s) first, pass self/other to them depending on selfIdx
  numBlocks = 4; % FIXME: There will be repeats
  Data.blocks.planned = cell(numBlocks, 1);
  Data.blocks.recorded = cell(0);
  Data.blocks.numRecorded = 0;
  for blockIdx = 1:numBlocks
    blockKind = medIdx(blockIdx);
    beneficiaryKind = selfIdx(blockIdx);
    withinKindIdx = sum(medIdx(1 : blockIdx) == blockKind);
    % withinBenefIdx = sum(selfIdx(1 : blockIdx) == beneficiaryKind);
    % NOTE: Unnecessary, because we're not generating blocks specifically for
    %   the self/other distinction, just adding it after the fact

    if blockKind == 1
      Data.blocks.planned{blockIdx} = struct('trials', ...
        medBlocks{withinKindIdx}, 'blockKind', blockKind, ...
        'beneficiaryKind', beneficiaryKind);
    else
      Data.blocks.planned{blockIdx} = struct('trials', ...
        monBlocks{withinKindIdx}, 'blockKind', blockKind, ...
        'beneficiaryKind', beneficiaryKind);
    end
  end
end

% Display blocks
firstBlockIdx = Data.blocks.numRecorded + 1;
lastBlockIdx = 4; % FIXME: Derive from settings

if exist('observer', 'var')
  for blockIdx = firstBlockIdx:lastBlockIdx
    % Determine monetary or medical
    if Data.blocks.planned{blockIdx}.blockKind == 0
      blockSettings = monSettings;
    else
      blockSettings = medSettings;
    end

    % Determine self or other
    if Data.blocks.planned{blockIdx}.beneficiaryKind == 0
      blockSettings.game.block.beneficiaryKind = 0;
      blockSettings.game.block.beneficiaryText = 'Friend';
    else
      blockSettings.game.block.beneficiaryKind = 1;
      blockSettings.game.block.beneficiaryText = 'Myself';
    end
    blockSettings.game.block.name = [blockSettings.game.block.name ' / ' ...
      blockSettings.game.block.beneficiaryText];

    blockSettings.game.trials = Data.blocks.planned{blockIdx}.trials(1:3, :);
    Data = runBlock(Data, blockSettings);
  end
else
  % Run practice -- only first n trials of first two blocks?
  numSelect = 1;
  for blockIdx = 2:3 % Known to be two different blocks
    % Determine medical or monetary
    if Data.blocks.planned{blockIdx}.blockKind == 0
      blockSettings = monSettings;
    else
      blockSettings = medSettings;
    end

    % Determine self or other
    if Data.blocks.planned{blockIdx}.beneficiaryKind == 0
      blockSettings.game.block.beneficiaryKind = 0;
      blockSettings.game.block.beneficiaryText = 'Friend';
    else
      blockSettings.game.block.beneficiaryKind = 1;
      blockSettings.game.block.beneficiaryText = 'Myself';
    end
    blockSettings.game.block.name = [blockSettings.game.block.name ' / ' ...
      blockSettings.game.block.beneficiaryText];

    randomIdx = randperm(blockSettings.game.block.length, numSelect);
    blockSettings.game.trials = Data.blocks.planned{blockIdx}.trials(randomIdx, :);
    Data = runBlock(Data, blockSettings);
  end
end

% Close window
Screen('CloseAll');
end

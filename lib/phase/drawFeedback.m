function [ trialData ] = drawFeedback(trialData, trialSettings, blockSettings, callback)
% DRAWFEEDBACK Based on the value in `trialData.choice`, it draws the feedback
%   that confirms to the player which option they chose (or whether they chose
%   at all) and displays it for `blockSettings.game.durations.feedback`. Can be
%   re-used for tasks that offer two options in a choice.

W = blockSettings.device.screenDims(3); % width
H = blockSettings.device.screenDims(4); % height
center = [W / 2, H / 2];
windowPtr = blockSettings.device.windowPtr;

feedbackSize = blockSettings.objects.feedback.dims;
pxOffCenter = [0.05 * W, 0];

% NOTE: Use structs / element class?
button1 = centerRectDims(center, feedbackSize, -pxOffCenter);
button2 = centerRectDims(center, feedbackSize, pxOffCenter);

button1_color = blockSettings.objects.feedback.colorNoAnswer;
button2_color = blockSettings.objects.feedback.colorNoAnswer;

%% Record choice & assign feedback color
% TODO: If a function can translate choice + refSide into a lottery choice,
% this could flag stochastic dominance violations as they happen
if trialData.choice == 1
    button1_color = blockSettings.objects.feedback.colorAnswer;
elseif trialData.choice == 2
    button2_color = blockSettings.objects.feedback.colorAnswer;
end

%% Display feedback (two squares)
Screen('FillRect', windowPtr, button1_color, button1);
Screen('FillRect', windowPtr, button2_color, button2);

% Re-draw reference and note feedback length
Screen('flip', windowPtr); % NOTE: This makes no sense. Why are we using it if we're not taking our time measurements from it?

trialData.feedbackStartTime = datevec(now);
trialData = timeFeedback(trialData, trialSettings, blockSettings);

if exist('callback', 'var') && isa(callback, 'function_handle')
  trialData = callback(trialData, trialSettings, blockSettings);
end
end

% Local function with timing responsibility
function trialData = timeFeedback(trialData, trialSettings, blockSettings)
  elapsedTime = etime(datevec(now), trialData.feedbackStartTime);
  while elapsedTime < blockSettings.game.durations.feedback
    elapsedTime = etime(datevec(now), trialData.feedbackStartTime);
  end
end

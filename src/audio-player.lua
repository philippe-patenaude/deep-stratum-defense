local audioPlayer = {}

audioPlayer.sourceMap = {}

audioPlayer.masterVolume = 1
audioPlayer.effectVolume = 1
audioPlayer.musicVolume = 1
audioPlayer.ambientVolume = 1

--[[
    @param options (optional)
        - volume A value between 0 and 1.
        - loop True or false. Plays the audio in a loop. Defaults to false.
        - pitch Calculated with regard to 1 being the base pitch.
            Each reduction by 50 percent equals a pitch shift of -12 semitones
            (one octave reduction). Each doubling equals a pitch shift of 12
            semitones (one octave increase). Zero is not a legal value.
        - type The type of audio to play. This affects what volume the
            audio will play at. In the future, it may also affect what effects
            are applied to the sound. Valid values include "MUSIC", "AMBIENT",
            and "EFFECT". If not set, the sound defaults to "EFFECT".
]]
function audioPlayer:play(source, options)
    options = options or {}
    local volume = options.volume or 1
    local pitch = options.pitch or 1
    local loop = options.loop or false
    local type = options.type or nil

    local typeVolume = nil
    if type == "EFFECT" or type == "" or not type then
        typeVolume = self.effectVolume
    elseif type == "MUSIC" then
        typeVolume = self.musicVolume
    elseif type == "AMBIENT" then
        typeVolume = self.ambientVolume
    else
        error('No such audio type "' .. type .. '".')
    end
    volume = volume * self.masterVolume * typeVolume
    local activeSource = nil
    if not options.source then
        if self.sourceMap[source] == nil then
            self.sourceMap[source] = {source}
        end
        for i,s in ipairs(self.sourceMap[source]) do
            if s:isPlaying() == false then
                activeSource = s
                break
            end
        end
        if activeSource == nil then
            -- There are no sounds available in the map to play.
            -- Create a clone of the source, add it to the map, and play it.
            activeSource = source:clone()
            table.insert(self.sourceMap[source], activeSource)
        end
    else
        activeSource = options.source
    end
    if options.update then
        if options.volume ~= nil then
            activeSource:setVolume(volume)
        end
        if options.pitch ~= nil then
            activeSource:setPitch(pitch)
        end
        if options.loop ~= nil then
            activeSource:setLooping(loop)
        end
    else
        activeSource:setVolume(volume)
        activeSource:setPitch(pitch)
        activeSource:setLooping(loop)
        love.audio.play(activeSource)
    end
    return activeSource
end

function audioPlayer:setProperties(source, options)
    options.source = source
    options.update = true
    self:play(null, options)
end

-- @param value A value between 0 and 1.
function audioPlayer:setMasterVolume(value)
    self.masterVolume = value
end

function audioPlayer:getMasterVolume()
    return self.ambientVolume
end

-- @param value A value between 0 and 1.
function audioPlayer:setEffectVolume(value)
    self.effectVolume = value
end

function audioPlayer:getEffectVolume()
    return self.ambientVolume
end

-- @param value A value between 0 and 1.
function audioPlayer:setMusicVolume(value)
    self.musicVolume = value
end

function audioPlayer:getMusicVolume()
    return self.ambientVolume
end

-- @param value A value between 0 and 1.
function audioPlayer:setAmbientVolume(value)
    self.ambientVolume = value
end

function audioPlayer:getAmbientVolume()
    return self.ambientVolume
end

return audioPlayer
on run argv
    if (count of argv) is 0 then
        set targetDevice to "iPad"
    else
        set targetDevice to item 1 of argv
    end if

    tell application "QuickTime Player"
        activate
        delay 1

        try
            close every document saving no
        end try

        delay 0.5
        new movie recording
    end tell

    delay 2

    tell application "System Events"
        tell process "QuickTime Player"
            set frontmost to true

            repeat 20 times
                if exists window 1 then exit repeat
                delay 0.2
            end repeat

            perform action "AXRaise" of window 1
            delay 0.5

            -- Open source dropdown
            click button 2 of window 1

            delay 1

            set foundDevice to false
            set allElements to entire contents

            repeat with el in allElements
                try
                    set elName to name of el as string

                    -- Prefer iPhone/iPad screen, not Camera/Microphone/Desk View
                    if elName contains targetDevice and elName does not contain "Camera" and elName does not contain "Microphone" and elName does not contain "Desk View" then
                        click el
                        set foundDevice to true
                        exit repeat
                    end if
                end try
            end repeat

            if foundDevice is false then
                error "Could not find screen option containing: " & targetDevice
            end if

            delay 1

            -- Audio preview / unmute
            my ensureAudioUnmuted()

            return "QUICKTIME_READY=" & targetDevice
        end tell
    end tell
end run

on ensureAudioUnmuted()
    tell application "System Events"
        tell process "QuickTime Player"
            -- Try to raise volume first
            try
                set value of slider 1 of window 1 to 1.0
            end try

            delay 0.3

            -- Button 1 is usually the mute/unmute button.
            -- If it says "unmute", click it.
            try
                set audioButtonDescription to description of button 1 of window 1 as string

                if audioButtonDescription contains "unmute" or audioButtonDescription contains "Unmute" then
                    click button 1 of window 1
                end if
            end try
        end tell
    end tell
end ensureAudioUnmuted
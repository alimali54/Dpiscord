Option Explicit

Dim fso, shell, basePath, userFolder, discordPath, exePath, command, folder
Set fso = CreateObject("Scripting.FileSystemObject")
Set shell = CreateObject("WScript.Shell")

basePath = "C:\Users"
For Each userFolder In fso.GetFolder(basePath).SubFolders
    discordPath = userFolder.Path & "\AppData\Local\Discord"
    If fso.FolderExists(discordPath) Then
        exePath = FindDiscordExe(discordPath)
        If Not exePath = "" Then
            command = "cmd /c start """" /b proxychains_win32_x64.exe -f proxychains.conf """ & exePath & """"
            shell.Run command, 0, False
            Exit For ' İstersen tüm kullanıcıları denemek için bu satırı silebilirsin
        End If
    End If
Next

Function FindDiscordExe(folderPath)
    Dim folderQueue, currentFolder, subFolder, file
    Set folderQueue = CreateObject("Scripting.Dictionary")
    folderQueue.Add folderPath, folderPath
    FindDiscordExe = ""

    Do Until folderQueue.Count = 0
        For Each currentFolder In folderQueue
            folderQueue.Remove currentFolder
            If fso.FolderExists(currentFolder) Then
                For Each file In fso.GetFolder(currentFolder).Files
                    If LCase(fso.GetFileName(file)) = "discord.exe" Then
                        FindDiscordExe = file.Path
                        Exit Function
                    End If
                Next
                For Each subFolder In fso.GetFolder(currentFolder).SubFolders
                    folderQueue.Add subFolder.Path, subFolder.Path
                Next
            End If
        Next
    Loop
End Function

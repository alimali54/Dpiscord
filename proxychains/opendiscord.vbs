Option Explicit
Dim fso, shell, basePath, userFolder, discordPath, exePath, command, pName, processes
Set fso = CreateObject("Scripting.FileSystemObject")
Set shell = CreateObject("WScript.Shell")

' --- Mevcut süreçleri zorla sonlandır ---
processes = Array("ciadpi.exe", "proxychains_win32_x64.exe", "discord.exe")
For Each pName In processes
    shell.Run "taskkill /F /T /IM " & pName, 0, True
Next
WScript.Sleep 100

' --- Otomatik Eklenen ciadpi ---
shell.Run "cmd /c start """" /b ""C:\Users\Meryem\Desktop\DPI\D(p)iscord\byedpi\ciadpi.exe"" -r 1+s -p 8848", 0, False
WScript.Sleep 200

basePath = "C:\Users"
For Each userFolder In fso.GetFolder(basePath).SubFolders
    discordPath = userFolder.Path & "\AppData\Local\Discord"
    If fso.FolderExists(discordPath) Then
        exePath = FindDiscordExe(discordPath)
        If Not exePath = "" Then
            command = "cmd /c start """" /b proxychains_win32_x64.exe -f proxychains.conf """ & exePath & """"
            shell.Run command, 0, False
            Exit For
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
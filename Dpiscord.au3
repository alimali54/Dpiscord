#NoTrayIcon
#include <ButtonConstants.au3>
#include <GUIConstantsEx.au3>
#include <AutoItConstants.au3>
#include <File.au3>
#include <Array.au3>

; ================= GLOBAL =================
Global $gCancel = False

; --- YAPILANDIRMA ---
Local $gdpiDir = @ScriptDir & "\byedpi"
Local $ciadpiPath = $gdpiDir & "\ciadpi.exe"
Local $strategyFile = $gdpiDir & "\strategies.txt"
Local $vbsPath = @ScriptDir & "\proxychains\opendiscord.vbs"
Local $testUrl = "https://updates.discord.com"
Local $proxy = "127.0.0.1:8848"
Local $discordIco = @LocalAppDataDir & "\Discord\app.ico"

; --- ARAYÜZ (Label Tamamen Kaldırıldı) ---
Local $hGUI = GUICreate("DPI Strateji & Kısayol", 450, 100) ; Yükseklik azaltıldı
GUISetBkColor(0xF0F0F0)

; Ana Buton
Local $idBtn = GUICtrlCreateButton("Sistem Analiz Ediliyor...", 20, 20, 410, 60)
GUICtrlSetFont(-1, 10, 800, 0, "Segoe UI")
GUICtrlSetState($idBtn, $GUI_DISABLE)
GUISetState(@SW_SHOW)

; --- AÇILIŞ DNS KONTROLÜ ---
If test_dns_poisoning() Then
    GUICtrlSetData($idBtn, "HATA: DNS Zehirlenmesi Saptandı. YogaDNS ile çözebilirsiniz.")
    GUICtrlSetColor($idBtn, 0xFF0000)
Else
    GUICtrlSetData($idBtn, "ByeDPI stratejisi bul ve Masaüstüne kısayol oluştur")
    GUICtrlSetColor($idBtn, 0x008800)
    GUICtrlSetState($idBtn, $GUI_ENABLE)
EndIf

; ================= ANA DÖNGÜ =================
While 1
    Switch GUIGetMsg()
        Case $GUI_EVENT_CLOSE
            $gCancel = True
            ProcessClose("ciadpi.exe")
            Exit
        Case $idBtn
            $gCancel = False
            GUICtrlSetState($idBtn, $GUI_DISABLE)
            StratejileriDene()
            ; İşlem bittikten sonra (iptal edilmediyse) buton aktifleşir
            If Not $gCancel Then GUICtrlSetState($idBtn, $GUI_ENABLE)
    EndSwitch
WEnd

; ================= FONKSİYONLAR =================

Func StratejileriDene()
    Local $aStrategies
    If Not FileExists($strategyFile) Then
        GUICtrlSetData($idBtn, "HATA: strategies.txt bulunamadı!")
        Return
    EndIf
    _FileReadToArray($strategyFile, $aStrategies)

    For $i = 1 To $aStrategies[0]
        If _CheckCancel() Then Return
        Local $currentParam = StringStripWS($aStrategies[$i], 3)
        If $currentParam = "" Then ContinueLoop

        ; Durum bilgisi butonun üzerine yazılıyor
        GUICtrlSetData($idBtn, "Deneniyor (" & $i & "/" & $aStrategies[0] & "): " & $currentParam)
        GUICtrlSetColor($idBtn, 0x0000FF)

        ProcessClose("ciadpi.exe")
        ProcessWaitClose("ciadpi.exe", 2)
        Run('"' & $ciadpiPath & '" ' & $currentParam & " -p 8848", $gdpiDir, @SW_HIDE)

        If _SmartWait(3000) Then Return

        If TestSocksConnection() Then
            ; 1. Stratejiyi dosyada en üste al
            Local $newContent = $currentParam & @CRLF
            For $j = 1 To $aStrategies[0]
                Local $p = StringStripWS($aStrategies[$j], 3)
                If $p <> "" And $p <> $currentParam Then $newContent &= $p & @CRLF
            Next
            Local $hFile = FileOpen($strategyFile, 2)
            FileWrite($hFile, StringStripWS($newContent, 2))
            FileClose($hFile)

            ; 2. VBS Dosyasını Güncelle
            UpdateVBS($currentParam)

            ; 3. MASAÜSTÜNE KISAYOL OLUŞTUR
            Local $shortcutPath = @DesktopDir & "\Discord (DPI).lnk"
            FileCreateShortcut($vbsPath, $shortcutPath, @ScriptDir & "\proxychains", "", "Discord DPI Launcher", $discordIco)

            ProcessClose("ciadpi.exe")
            
            ; Final Mesajı Butonun Üstünde
            GUICtrlSetData($idBtn, "BAŞARILI! Kısayol Masaüstüne Atıldı.")
            GUICtrlSetColor($idBtn, 0x008800)
            ;MsgBox(64, "Tamamlandı", "İşlem başarılı! Masaüstündeki kısayolu kullanabilirsiniz.")
            Return
        EndIf
    Next
    
    GUICtrlSetData($idBtn, "HATA: Hiçbir strateji çalışmadı!")
    GUICtrlSetColor($idBtn, 0xFF0000)
EndFunc

; ---------- YARDIMCI FONKSİYONLAR ----------

Func _CheckCancel()
    Local $msg = GUIGetMsg()
    If $msg = $GUI_EVENT_CLOSE Or $gCancel Then
        $gCancel = True
        ProcessClose("ciadpi.exe")
        GUICtrlSetData($idBtn, "İşlem İptal Edildi!")
        GUICtrlSetColor($idBtn, 0x000000)
        Return True
    EndIf
    Return False
EndFunc

Func _SmartWait($ms)
    Local $t = TimerInit()
    While TimerDiff($t) < $ms
        If _CheckCancel() Then Return True
        Sleep(50)
    WEnd
    Return False
EndFunc

Func UpdateVBS($param)
    ; (v1.3'teki taskkill'li VBS içeriği buraya gelecek...)
    Local $vbsContent = 'Option Explicit' & @CRLF & _
        'Dim fso, shell, basePath, userFolder, discordPath, exePath, command, pName, processes' & @CRLF & _
        'Set fso = CreateObject("Scripting.FileSystemObject")' & @CRLF & _
        'Set shell = CreateObject("WScript.Shell")' & @CRLF & @CRLF & _
        ''' --- Mevcut süreçleri zorla sonlandır ---' & @CRLF & _
        'processes = Array("ciadpi.exe", "proxychains_win32_x64.exe", "discord.exe")' & @CRLF & _
        'For Each pName In processes' & @CRLF & _
        '    shell.Run "taskkill /F /T /IM " & pName, 0, True' & @CRLF & _
        'Next' & @CRLF & _
        'WScript.Sleep 100' & @CRLF & @CRLF & _
        ''' --- Otomatik Eklenen ciadpi ---' & @CRLF & _
        'shell.Run "cmd /c start """" /b ""' & $ciadpiPath & '"" ' & $param & " -p 8848" & '", 0, False' & @CRLF & _
        'WScript.Sleep 200' & @CRLF & @CRLF & _
        'basePath = "C:\Users"' & @CRLF & _
        'For Each userFolder In fso.GetFolder(basePath).SubFolders' & @CRLF & _
        '    discordPath = userFolder.Path & "\AppData\Local\Discord"' & @CRLF & _
        '    If fso.FolderExists(discordPath) Then' & @CRLF & _
        '        exePath = FindDiscordExe(discordPath)' & @CRLF & _
        '        If Not exePath = "" Then' & @CRLF & _
        '            command = "cmd /c start """" /b proxychains_win32_x64.exe -f proxychains.conf """ & exePath & """"' & @CRLF & _
        '            shell.Run command, 0, False' & @CRLF & _
        '            Exit For' & @CRLF & _
        '        End If' & @CRLF & _
        '    End If' & @CRLF & _
        'Next' & @CRLF & @CRLF & _
        'Function FindDiscordExe(folderPath)' & @CRLF & _
        '    Dim folderQueue, currentFolder, subFolder, file' & @CRLF & _
        '    Set folderQueue = CreateObject("Scripting.Dictionary")' & @CRLF & _
        '    folderQueue.Add folderPath, folderPath' & @CRLF & _
        '    FindDiscordExe = ""' & @CRLF & _
        '    Do Until folderQueue.Count = 0' & @CRLF & _
        '        For Each currentFolder In folderQueue' & @CRLF & _
        '            folderQueue.Remove currentFolder' & @CRLF & _
        '            If fso.FolderExists(currentFolder) Then' & @CRLF & _
        '                For Each file In fso.GetFolder(currentFolder).Files' & @CRLF & _
        '                    If LCase(fso.GetFileName(file)) = "discord.exe" Then' & @CRLF & _
        '                        FindDiscordExe = file.Path' & @CRLF & _
        '                        Exit Function' & @CRLF & _
        '                    End If' & @CRLF & _
        '                Next' & @CRLF & _
        '                For Each subFolder In fso.GetFolder(currentFolder).SubFolders' & @CRLF & _
        '                    folderQueue.Add subFolder.Path, subFolder.Path' & @CRLF & _
        '                Next' & @CRLF & _
        '            End If' & @CRLF & _
        '        Next' & @CRLF & _
        '    Loop' & @CRLF & 'End Function'
    
    Local $hFile = FileOpen($vbsPath, 2)
    FileWrite($hFile, $vbsContent)
    FileClose($hFile)
EndFunc

Func TestSocksConnection()
    Local $cmd = 'curl -I --socks5-hostname ' & $proxy & ' ' & $testUrl & ' --connect-timeout 4'
    Local $pid = Run(@ComSpec & ' /c ' & $cmd, "", @SW_HIDE, $STDOUT_CHILD)
    Local $out = ""
    Local $t = TimerInit()
    While TimerDiff($t) < 5000
        $out &= StdoutRead($pid)
        If @error Or _CheckCancel() Then ExitLoop
        Sleep(100)
    WEnd
    Return StringInStr($out, "HTTP/") > 0
EndFunc

Func test_dns_poisoning()
    Local $target = "updates.discord.com"
    Local $ipLocal = _GetIPFromNS($target, "")
    Local $ipSafe = _GetIPFromNS($target, "1.1.1.1")
    If $ipLocal = "" Or $ipSafe = "" Then Return False
    Local $a = StringSplit($ipLocal, ".")
    Local $b = StringSplit($ipSafe, ".")
    Return ($a[1] <> $b[1] Or $a[2] <> $b[2])
EndFunc

Func _GetIPFromNS($host, $dns)
    Local $cmd = ' /c nslookup ' & $host
    If $dns <> "" Then $cmd &= " " & $dns
    Local $pid = Run(@ComSpec & $cmd, "", @SW_HIDE, $STDOUT_CHILD)
    Local $out = ""
    While 1
        $out &= StdoutRead($pid)
        If @error Then ExitLoop
    WEnd
    Local $m = StringRegExp($out, "(?i)Address(?:es)?:\s+([\d\.]+)", 3)
    If Not @error And UBound($m) > 0 Then Return $m[UBound($m) - 1]
    Return ""
EndFunc
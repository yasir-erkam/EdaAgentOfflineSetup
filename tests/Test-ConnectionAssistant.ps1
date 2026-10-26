[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$RuntimePath)
# UIAutomation behavior fixture emulates the native callback, not Pascal or Altium 26.7.1 compatibility.
$ErrorActionPreference='Stop'
$repo=Split-Path $PSScriptRoot -Parent
if (@(Get-Process x2,dxp -ErrorAction SilentlyContinue).Count -gt 0) { throw 'Close real Altium before this isolated sole-process fixture test; no existing process was changed.' }
$root=Join-Path $repo ('.work\assistant-behavior-'+[Guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($root)
[void][IO.Directory]::CreateDirectory((Join-Path $root 'workspace'))
[void][IO.Directory]::CreateDirectory((Join-Path $root 'scripts'))
Copy-Item "$repo\installer\Connection-Assistant.ps1","$repo\payload\setup_logging.ps1","$repo\payload\altium\altium_menu.py" $root -Force
[IO.File]::WriteAllText("$root\installation.json",'{"backend":"altium"}')
[IO.File]::WriteAllText("$root\workspace\eda-menu-enabled",'1')
[IO.File]::WriteAllText("$root\scripts\Altium_API.PrjScr",'fixture only')
Copy-Item -LiteralPath (Resolve-Path -LiteralPath $RuntimePath).Path -Destination "$root\runtime" -Recurse
$source=@'
using System;
using System.IO;
using System.Threading;
using System.Collections.Generic;
using System.Web.Script.Serialization;
public class Fixture {
 static JavaScriptSerializer j=new JavaScriptSerializer();
 static string root=AppDomain.CurrentDomain.BaseDirectory, w=Path.Combine(root,"workspace"), caller="111-222", session="", rev="0", target="";
 static bool running=false;
 static Dictionary<string,object> Read(string p){return j.Deserialize<Dictionary<string,object>>(File.ReadAllText(p));}
 static string S(Dictionary<string,object> d,string k){return d.ContainsKey(k)?Convert.ToString(d[k]):"";}
 static void Write(string p,object d){File.WriteAllText(p+".tmp",j.Serialize(d));File.Move(p+".tmp",p);}
 static Dictionary<string,object> Data(){return new Dictionary<string,object>{{"caller_id",caller},{"session_id",session},{"integration_version",2},{"running",running},{"revision",rev},{"target_project",target},{"active_document","D:\\Türkçe tasarım\\A.PcbDoc"},{"projects",new[]{"D:\\Türkçe tasarım\\A.PrjPcb","D:\\Other\\A.PrjPcb"}}};}
 static void Publish(){File.WriteAllText(Path.Combine(root,"current.json"),j.Serialize(Data()));}
 public static void Main(string[] args){
 if(args.Length>0){if(args.Length!=1||!args[0].StartsWith("-RScriptingSystem:RunScript(ProjectName=")||!args[0].EndsWith("|ProcName=ConnectionAssistant.pas>DispatchConnectionAssistant)")){Environment.Exit(3);} File.AppendAllText(Path.Combine(root,"forwarded.log"),string.Join(" ",args)+Environment.NewLine);return;}
 File.WriteAllText(Path.Combine(w,"eda-assistant-caller-"+caller+".json"),j.Serialize(new{caller_id=caller}));
 Publish();
 while(!File.Exists(Path.Combine(root,"finish"))){try{
 string intent=Path.Combine(w,"eda-assistant-launch.lock","intent.json");
 if(File.Exists(intent)&&File.Exists(Path.Combine(root,"forwarded.log"))){Thread.Sleep(180);var d=Read(intent);File.Delete(intent);string action=S(d,"action"),nonce=S(d,"nonce");
 File.AppendAllText(Path.Combine(root,"events.log"),j.Serialize(new{action=action,caller_id=S(d,"caller_id"),session_id=S(d,"session_id")})+Environment.NewLine);
 if((action!="prepare"&&action!="start")||(S(d,"caller_id")!=""&&S(d,"caller_id")!=caller)||(S(d,"caller_id")!=""&&S(d,"session_id")!=session)){Write(Path.Combine(w,"eda-assistant-launch.lock","response-"+nonce+".json"),new{nonce=nonce,error="Calling Altium context changed."});continue;}
 if(action=="start"){running=true;session="333-"+DateTime.UtcNow.Ticks;rev=session;Directory.CreateDirectory(Path.Combine(w,"eda-menu-session.lock"));Publish();}
 var data=Data();data["nonce"]=nonce;Write(Path.Combine(w,"eda-assistant-launch.lock","response-"+nonce+".json"),data);
 }
 foreach(string p in Directory.GetFiles(w,"request_*.json")){if(!running)continue;var d=Read(p);var par=(Dictionary<string,object>)d["params"];string command=S(d,"command"),id=S(d,"id");File.AppendAllText(Path.Combine(root,"requests.log"),File.ReadAllText(p)+Environment.NewLine);object reply;
 if(S(par,"_eda_caller_id")!=caller||S(par,"_eda_session_id")!=session||File.Exists(Path.Combine(root,"stale"))){reply=new{protocol_version=2,id=id,success=false,error=new{message="Calling Altium session changed; reopen Connection Assistant."}};}
 else {if(command=="eda_menu.select"){target=S(par,"project_path");rev=DateTime.UtcNow.Ticks.ToString();} if(command=="eda_menu.disconnect"){running=false;target="";File.WriteAllText(Path.Combine(w,"eda-menu-state.json"),j.Serialize(Data()));Directory.Delete(Path.Combine(w,"eda-menu-session.lock"));Publish();} reply=new{protocol_version=2,id=id,success=true,data=Data()};}
 Write(Path.Combine(w,"response_"+id+".json"),reply);File.Delete(p);
 }
 }catch(Exception e){File.AppendAllText(Path.Combine(root,"fixture-errors.log"),e.ToString()+Environment.NewLine);}Thread.Sleep(30);}
 }
}
'@
if (!(Test-Path "$root\x2.exe")) { Add-Type -TypeDefinition $source -ReferencedAssemblies System.Web.Extensions -OutputAssembly "$root\x2.exe" -OutputType ConsoleApplication }
Write-Output "FIXTURE_ROOT=$root"

$ErrorActionPreference='Stop'
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
$fixture=Start-Process "$root\x2.exe" -PassThru
$ui=$null
function Window {
 $condition=New-Object Windows.Automation.PropertyCondition([Windows.Automation.AutomationElement]::ProcessIdProperty,$ui.Id)
 [Windows.Automation.AutomationElement]::RootElement.FindFirst([Windows.Automation.TreeScope]::Children,$condition)
}
function Controls { $script:window.FindAll([Windows.Automation.TreeScope]::Descendants,[Windows.Automation.Condition]::TrueCondition) }
function Button([string]$name){foreach($c in (Controls)){if($c.Current.Name.TrimEnd([char]0x2026) -eq $name.TrimEnd([char]0x2026) -and $c.Current.ControlType -eq [Windows.Automation.ControlType]::Button){return $c}};throw "Button missing: $name"}
function Click([string]$name){$b=Button $name;$b.GetCurrentPattern([Windows.Automation.InvokePattern]::Pattern).Invoke()}
function OutputText {foreach($c in (Controls)){if($c.Current.ClassName -match 'EDIT'){ $p=$null;if($c.TryGetCurrentPattern([Windows.Automation.TextPattern]::Pattern,[ref]$p)){return $p.DocumentRange.GetText(-1)};if($c.TryGetCurrentPattern([Windows.Automation.ValuePattern]::Pattern,[ref]$p)){return $p.Current.Value}}};return ''}
function AwaitText([string]$text){$deadline=(Get-Date).AddSeconds(18);do{Start-Sleep -Milliseconds 150;$value=OutputText;if($value.Contains($text)){Write-Output "PASS: UI text $text";Write-Output $value;return}}while((Get-Date)-lt $deadline);foreach($c in (Controls)){Write-Output ($c.Current.ControlType.ProgrammaticName+' '+$c.Current.ClassName+' '+$c.Current.Name)};throw "Expected '$text', got '$value'"}
function Close-Assistant {
 if($script:ui -and !$script:ui.HasExited){$script:ui.CloseMainWindow()|Out-Null;if(!$script:ui.WaitForExit(5000)){throw 'Assistant did not close after completing operation'}}
}
function Open-Assistant([string]$action='Show',[string]$caller='111-222',[string]$session='') {
 Close-Assistant
 $arguments=@('-NoProfile','-STA','-ExecutionPolicy','Bypass','-File',('"'+$root+'\Connection-Assistant.ps1"'),'-Language','english','-CallerId',$caller,'-Action',$action)
 if($session){$arguments+=@('-SessionId',$session)}
 $script:ui=Start-Process powershell.exe -ArgumentList $arguments -PassThru -RedirectStandardOutput "$root\ui-$action-stdout.log" -RedirectStandardError "$root\ui-$action-stderr.log"
 $deadline=(Get-Date).AddSeconds(12);do{Start-Sleep -Milliseconds 100;$script:window=Window}while(!$window -and (Get-Date)-lt $deadline)
 if(!$window){throw "Assistant window unavailable for $action"}
}
function Current-Session { (Get-Content "$root\current.json" -Raw -Encoding UTF8|ConvertFrom-Json).session_id }
function Events { if(Test-Path "$root\events.log"){Get-Content "$root\events.log" -Encoding UTF8|ForEach-Object {$_|ConvertFrom-Json}} }
function Requests { if(Test-Path "$root\requests.log"){Get-Content "$root\requests.log" -Encoding UTF8|ForEach-Object {$_|ConvertFrom-Json}} }
function Assert-Delta([int]$prepare,[int]$start,[int]$status,[int]$disconnect,[int]$eventOffset,[int]$requestOffset) {
 Start-Sleep -Milliseconds 650
 $events=@(Events|Select-Object -Skip $eventOffset);$requests=@(Requests|Select-Object -Skip $requestOffset)
 if(@($events|Where-Object action -eq 'prepare').Count -ne $prepare -or @($events|Where-Object action -eq 'start').Count -ne $start -or @($requests|Where-Object command -eq 'eda_menu.status').Count -ne $status -or @($requests|Where-Object command -eq 'eda_menu.disconnect').Count -ne $disconnect){throw ('Unexpected action counts: '+($events|ConvertTo-Json -Compress)+' / '+($requests|ConvertTo-Json -Compress))}
 if($prepare -and (!$events.Count -or $events[0].action -ne 'prepare')){throw 'Initial action ran before prepare'}
 Write-Output "PASS: prepare=$prepare start=$start status=$status disconnect=$disconnect, no duplicate initial action"
}
try {
 Start-Sleep -Milliseconds 300
 $ui=Start-Process powershell.exe -ArgumentList @('-NoProfile','-STA','-ExecutionPolicy','Bypass','-File',('"'+$root+'\Connection-Assistant.ps1"'),'-Language','english') -PassThru -RedirectStandardOutput "$root\ui-stdout.log" -RedirectStandardError "$root\ui-stderr.log"
 $deadline=(Get-Date).AddSeconds(12);do{Start-Sleep -Milliseconds 100;$script:window=Window}while(!$window -and (Get-Date)-lt $deadline)
 if(!$window){throw 'Assistant window unavailable'}
 Write-Output ('WINDOW: '+$window.Current.Name)
 AwaitText 'Altium session bound.'
 Click 'Start connection'
 AwaitText 'Bridge is responding.'
 Click 'Connection status'
 AwaitText 'Bridge is responding.'
 $combo=@(Controls | Where-Object {$_.Current.ControlType -eq [Windows.Automation.ControlType]::ComboBox})[0]
 $combo.GetCurrentPattern([Windows.Automation.ExpandCollapsePattern]::Pattern).Expand()
 Start-Sleep -Milliseconds 100
 $item=$window.FindFirst([Windows.Automation.TreeScope]::Descendants,(New-Object Windows.Automation.PropertyCondition([Windows.Automation.AutomationElement]::NameProperty,'D:\Türkçe tasarım\A.PrjPcb')))
 if(!$item){throw 'Full-path project choice unavailable'}
 $item.GetCurrentPattern([Windows.Automation.SelectionItemPattern]::Pattern).Select()
 Click 'Target project…'
 AwaitText 'Target project: D:\Türkçe tasarım\A.PrjPcb'
 Click 'Help and troubleshooting…'
 AwaitText 'Menu setup:'
 if(!(Button 'Reconnect')){throw 'Reconnect unavailable'}
 Click 'Disconnect'
 AwaitText 'Disconnected. Documents were not saved; projects were left open.'
 Click 'Start connection'
 AwaitText 'Bridge is responding.'
 Click 'Reconnect'
 AwaitText 'Bridge is responding.'
 [IO.File]::WriteAllText("$root\stale",'1')
 Click 'Connection status'
 AwaitText 'Operation was not confirmed:'
 $requests=@(Get-Content "$root\requests.log" -Encoding UTF8 | ForEach-Object {$_|ConvertFrom-Json})
 if(@($requests|Where-Object {$_.command -match 'save|stop_server'}).Count){throw 'Unsafe save/legacy stop command sent'}
 if(@($requests|Where-Object {$_.command -eq 'eda_menu.disconnect'}).Count -ne 2){throw 'Disconnect/reconnect IPC not observed'}
 if(!(Test-Path "$root\forwarded.log")){throw 'Actual executable forwarding was not observed'}
 if(@($requests|Where-Object {$_.params._eda_caller_id -ne '111-222' -or !$_.params._eda_session_id}).Count){throw 'Request lost immutable caller/session binding'}
 $sessions=@($requests|ForEach-Object {$_.params._eda_session_id}|Select-Object -Unique)
 if($sessions.Count -ne 3){throw 'Initial start, restart and reconnect did not rotate session identity'}
 $last=$requests[-1]
 if($last.command -ne 'eda_menu.status' -or $last.params._eda_session_id -ne $sessions[-1]){throw 'Stale status request was silently rebound'}
 Remove-Item "$root\stale"
 # Each launch below mirrors the native menu's validated Action/CallerId/SessionId arguments.
 $e=@(Events).Count;$r=@(Requests).Count;$session=Current-Session
 Open-Assistant 'Show' '111-222' $session
 AwaitText 'Altium session bound.'
 Assert-Delta 1 0 0 0 $e $r
 $e=@(Events).Count;$r=@(Requests).Count
 Open-Assistant 'Status' '111-222' $session
 AwaitText 'Bridge is responding.'
 Assert-Delta 1 0 1 0 $e $r
 $e=@(Events).Count;$r=@(Requests).Count
 Open-Assistant 'Disconnect' '111-222' $session
 AwaitText 'Disconnected. Documents were not saved; projects were left open.'
 Assert-Delta 1 0 0 1 $e $r
 if((Get-Content "$root\current.json" -Raw|ConvertFrom-Json).running){throw 'Disconnect did not stop fixture bridge'}
 $e=@(Events).Count;$r=@(Requests).Count
 Open-Assistant 'Status' '111-222' $session
 AwaitText 'Operation was not confirmed:'
 Assert-Delta 1 0 0 0 $e $r
 if((Get-Content "$root\current.json" -Raw|ConvertFrom-Json).running){throw 'Status started stopped bridge'}
 $e=@(Events).Count;$r=@(Requests).Count
 Open-Assistant 'Start' '111-222' $session
 AwaitText 'Bridge is responding.'
 Assert-Delta 1 1 1 0 $e $r
 $e=@(Events).Count;$r=@(Requests).Count;$session=Current-Session
 Open-Assistant 'Reconnect' '111-222' $session
 AwaitText 'Bridge is responding.'
 Assert-Delta 1 1 1 1 $e $r
 if((Current-Session) -eq $session){throw 'Reconnect did not rotate session'}
 $e=@(Events).Count;$r=@(Requests).Count
 Open-Assistant 'Start' '111-222' $session
 AwaitText 'Operation was not confirmed:'
 Assert-Delta 1 0 0 0 $e $r
 if((Current-Session) -eq $session){throw 'Failed prepare unexpectedly adopted stale identity'}
 if(@(Requests|Where-Object {$_.command -match 'save|stop_server'}).Count){throw 'Direct action sent unsafe command'}
 if(Test-Path "$root\fixture-errors.log"){throw ('Native callback fixture errors: '+(Get-Content "$root\fixture-errors.log" -Raw))}
 Close-Assistant
 $e=@(Events).Count;$r=@(Requests).Count
 $invalid=Start-Process powershell.exe -ArgumentList @('-NoProfile','-STA','-ExecutionPolicy','Bypass','-File',('"'+$root+'\Connection-Assistant.ps1"'),'-CallerId','111-222','-Action','SaveDesign') -PassThru -RedirectStandardError "$root\invalid-action-stderr.log"
 if(!$invalid.WaitForExit(5000)){ $invalid.Kill();throw 'Invalid action was not rejected before opening UI' }
 if($invalid.ExitCode -eq 0){throw 'Invalid initial action was accepted'}
 Assert-Delta 0 0 0 0 $e $r
 Write-Output 'PASS: invalid Action rejected before callback or UI operation.'
 Write-Output 'PASS: Show remains prepare-only; direct actions execute once after prepare; stopped Status never starts; failed binding performs no action.'
 Write-Output "Evidence retained: $root"
 Write-Output 'PASS: actual PS5 WinForms + real Python controller + UIAutomation; native callback is emulated, not real Pascal/Altium compatibility evidence.'
} finally {
 if($ui -and !$ui.HasExited){$ui.CloseMainWindow()|Out-Null;[void]$ui.WaitForExit(2500);if(!$ui.HasExited){$ui.Kill()}}
 [IO.File]::WriteAllText("$root\finish",'1');[void]$fixture.WaitForExit(2500);if(!$fixture.HasExited){$fixture.Kill()}
}

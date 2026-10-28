; Установщик «Карнавальская Гонка». Сборка: ISCC KarnavalRace.iss (результат в ..\..\build).
; Файл сохранён в UTF-8 С BOM: без BOM компилятор прочтёт русский текст как ANSI.

#define AppName "Карнавальская Гонка"
#define AppExe "KarnavalskayaGonka.exe"
#define AppVer "0.1.1"
#define UserDataDir "Godot\app_userdata\Карнавальская Гонка"

[Setup]
AppId={{6B1E7C52-3D0A-4F8E-9A21-4B7C0C5E8A19}
AppName={#AppName}
AppVersion={#AppVer}
AppVerName={#AppName} {#AppVer}
AppPublisher=Harvester
DefaultDirName={autopf}\KarnavalRace
DisableProgramGroupPage=yes
DisableDirPage=no
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
SetupIconFile=app_icon.ico
UninstallDisplayIcon={app}\{#AppExe}
UninstallDisplayName={#AppName}
OutputDir=..\..\build
OutputBaseFilename=KarnavalskayaGonka_Setup_0.1.1
InfoBeforeFile=info_before.txt
DisableWelcomePage=no
WizardImageFile=img\porthole_tall.bmp
VersionInfoVersion=0.1.1.0
VersionInfoCompany=Harvester
VersionInfoDescription=Установщик: {#AppName}
VersionInfoProductName={#AppName}

[Languages]
Name: "russian"; MessagesFile: "compiler:Languages\Russian.isl"

[Messages]
SetupWindowTitle=Мастер установки: %1
WelcomeLabel1=Добро пожаловать на Карнавал!
WelcomeLabel2=Вас приветствует Мастер установки — существо терпеливое, как навигатор при пилоте-лихаче. Сейчас мы поселим на вашем компьютере гоночный каньон длиной в несколько сотен километров, двенадцать отчаянных пилотов (трезвых не обнаружено) и четыре корабля, каждый из которых хоть раз да терял двигатель. Закройте, пожалуйста, прочие программы: им лучше не знать, что будет дальше.
WizardInfoBefore=Прочтите, пока не поздно
WizardSelectDir=Куда парковать?
SelectDirDesc=Выберите ангар для игры
SelectDirLabel3=Игра встанет в указанную папку. Каньон велик, а скалы без потери живописности не сожмёшь, так что место понадобится (сколько — написано ниже). Хотите другой ангар — нажмите «Обзор». Не хотите думать — нажмите «Далее».
SelectDirBrowseLabel=Нажмите «Далее», когда ангар вас устроит.
WizardSelectTasks=Мелочи для комфорта
SelectTasksDesc=Что ещё сделать, пока мы паркуем корабли?
SelectTasksLabel2=Отметьте нужное и нажмите «Далее».
WizardReady=Ставки приняты
ReadyLabel1=Взносы внесены, ставки сделаны, корабли заправлены. Нажмите «Установить», и пути назад не будет (то есть будет, через деинсталлятор, но это уже позор).
WizardInstalling=Идёт заправка
InstallingLabel=Раскладываем каньон по полочкам
ButtonFinish=&Готово
ClickFinish=
FinishedHeadingLabel=Стартуем!
FinishedLabel=Установка закончена. Нажмите «Готово», чтобы выйти из мастера (из каньона так просто не выйти). Желаем лёгкого полёта и ни одной оторванной детали.
FinishedLabelNoIcons=Установка закончена. Нажмите «Готово», чтобы выйти из мастера (из каньона так просто не выйти). Желаем лёгкого полёта и ни одной оторванной детали.
ConfirmUninstall=Вы действительно хотите покинуть Карнавал? Каньон будет убран, пилоты распущены, ставки возвращены.
UninstalledAll=Карнавал свёрнут. Приходите ещё: каньон помнит всех, а букмекеры — тем более.
UninstalledMost=Карнавал свёрнут. Приходите ещё: каньон помнит всех, а букмекеры — тем более.

[CustomMessages]
russian.GameRunning=Игра сейчас запущена. Остановите гонку и закройте её, иначе мастер её не догонит.
russian.KillData=Стереть и ваши грамоты, рекорды и настройки? Они вам ещё пригодятся, но решать вам.

[Tasks]
Name: "desktopicon"; Description: "Значок на рабочем столе (чтобы стартовать, не сверяясь с картой)"; GroupDescription: "Мелочи для комфорта"; Flags: unchecked
Name: "startmenuicon"; Description: "Ярлык в меню «Пуск»"; GroupDescription: "Мелочи для комфорта"

[Files]
Source: "..\..\build\{#AppExe}"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\..\build\KarnavalskayaGonka.pck"; DestDir: "{app}"; Flags: ignoreversion
Source: "img\exit_side.bmp"; DestDir: "{app}"; DestName: "unins_exit.bmp"; Flags: ignoreversion
; картинки мастера: распаковываются во время работы из [Code]
Source: "img\porthole_tall.bmp"; Flags: dontcopy
Source: "img\space_tall.bmp"; Flags: dontcopy
Source: "img\about_side.bmp"; Flags: dontcopy
Source: "img\hangar_side.bmp"; Flags: dontcopy
Source: "img\bar_side.bmp"; Flags: dontcopy
Source: "img\cabin_side.bmp"; Flags: dontcopy
Source: "img\engine_side.bmp"; Flags: dontcopy

[Icons]
Name: "{autoprograms}\{#AppName}"; Filename: "{app}\{#AppExe}"; Tasks: startmenuicon
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExe}"; Tasks: desktopicon

[UninstallDelete]
; файлы, которые игра сама пишет рядом с exe при запуске
Type: files; Name: "{app}\flight_log.csv"
Type: files; Name: "{app}\tuning.json"

[Run]
Filename: "{app}\{#AppExe}"; Description: "Лететь немедленно!"; Flags: nowait postinstall skipifsilent runasoriginaluser

[Code]
function IsGameRunning(): Boolean;
var
  ResultCode: Integer;
  Tmp: String;
  S: AnsiString;
begin
  Result := False;
  Tmp := ExpandConstant('{tmp}\proc.txt');
  if Exec(ExpandConstant('{cmd}'), '/C tasklist /FI "IMAGENAME eq {#AppExe}" /NH > "' + Tmp + '"',
    '', SW_HIDE, ewWaitUntilTerminated, ResultCode) then
    if LoadStringFromFile(Tmp, S) then
      Result := Pos('{#AppExe}', String(S)) > 0;
end;

var
  SidePic: TBitmapImage;
  SideW: Integer;

{ Большая картинка слева на внутренних страницах: окно расширяется, страницы сдвигаются вправо.
  На приветствии и завершении страницы растягиваются на всю ширину, там своя боковая картинка. }
procedure InitializeWizard();
begin
  SideW := ScaleX(190);
  WizardForm.ClientWidth := WizardForm.ClientWidth + SideW;
  SidePic := TBitmapImage.Create(WizardForm);
  SidePic.Parent := WizardForm;
  SidePic.Stretch := True;
  SidePic.Anchors := [akLeft, akTop, akBottom];
  SidePic.SetBounds(0, 0, SideW, WizardForm.OuterNotebook.Height);
  WizardForm.WizardSmallBitmapImage.Visible := False;
end;

procedure LoadPic(Img: TBitmapImage; const Name: String);
begin
  ExtractTemporaryFile(Name);
  Img.Bitmap.LoadFromFile(ExpandConstant('{tmp}\' + Name));
end;

procedure Layout(Wide: Boolean);
var
  H, T: Integer;
begin
  H := WizardForm.OuterNotebook.Height;
  T := WizardForm.OuterNotebook.Top;
  SidePic.Visible := not Wide;
  if Wide then
    WizardForm.OuterNotebook.SetBounds(0, T, WizardForm.ClientWidth, H)
  else
    WizardForm.OuterNotebook.SetBounds(SideW, T, WizardForm.ClientWidth - SideW, H);
end;

procedure CurPageChanged(CurPageID: Integer);
begin
  case CurPageID of
    wpWelcome:
      begin
        Layout(True);
        LoadPic(WizardForm.WizardBitmapImage, 'porthole_tall.bmp');
      end;
    wpFinished:
      begin
        Layout(True);
        LoadPic(WizardForm.WizardBitmapImage2, 'space_tall.bmp');
      end;
  else
    begin
      Layout(False);
      case CurPageID of
        wpInfoBefore:  LoadPic(SidePic, 'about_side.bmp');
        wpSelectDir:   LoadPic(SidePic, 'hangar_side.bmp');
        wpSelectTasks: LoadPic(SidePic, 'bar_side.bmp');
        wpReady:       LoadPic(SidePic, 'cabin_side.bmp');
        wpInstalling:  LoadPic(SidePic, 'engine_side.bmp');
      end;
    end;
  end;
end;

procedure CurInstallProgressChanged(CurProgress, MaxProgress: Integer);
var
  P: Integer;
  T: String;
begin
  if MaxProgress <= 0 then Exit;
  P := (CurProgress * 100) div MaxProgress;
  if P < 15 then T := 'Разворачиваем каньон…'
  else if P < 30 then T := 'Раскрашиваем скалы в полоску…'
  else if P < 50 then T := 'Прикручиваем моторы (иногда даже к кораблям)…'
  else if P < 70 then T := 'Принимаем ставки на дальних кораблей…'
  else if P < 85 then T := 'Подкупаем судей (шутка!)…'
  else if P < 95 then T := 'Разливаем топливо и прочие жидкости…'
  else T := 'Ещё чуть-чуть, борт уже на старте…';
  WizardForm.StatusLabel.Caption := T;
end;

function PrepareToInstall(var NeedsRestart: Boolean): String;
begin
  Result := '';
  if IsGameRunning() then
    Result := CustomMessage('GameRunning');
end;

function InitializeUninstall(): Boolean;
begin
  Result := True;
  if IsGameRunning() then
  begin
    MsgBox(CustomMessage('GameRunning'), mbInformation, MB_OK);
    Result := False;
  end;
end;

procedure InitializeUninstallProgressForm();
var
  Pic: TBitmapImage;
  W, H, OldW: Integer;
  F: String;
begin
  W := ScaleX(190);
  OldW := UninstallProgressForm.OuterNotebook.Width;
  H := UninstallProgressForm.OuterNotebook.Height;
  UninstallProgressForm.ClientWidth := UninstallProgressForm.ClientWidth + W;
  UninstallProgressForm.OuterNotebook.SetBounds(W, UninstallProgressForm.OuterNotebook.Top, OldW, H);
  UninstallProgressForm.WizardSmallBitmapImage.Visible := False;
  F := ExpandConstant('{app}\unins_exit.bmp');
  if FileExists(F) then
  begin
    Pic := TBitmapImage.Create(UninstallProgressForm);
    Pic.Parent := UninstallProgressForm;
    Pic.Stretch := True;
    Pic.SetBounds(0, 0, W, H);
    Pic.Bitmap.LoadFromFile(F);
  end;
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
begin
  if CurUninstallStep = usPostUninstall then
    if MsgBox(CustomMessage('KillData'), mbConfirmation, MB_YESNO or MB_DEFBUTTON2) = IDYES then
      DelTree(ExpandConstant('{userappdata}\{#UserDataDir}'), True, True, True);
end;

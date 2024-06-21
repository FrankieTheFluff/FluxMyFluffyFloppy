{
UnTerminal 1.0
===============
Por Tito Hinostroza 02/10/2020

Description
===========
Lazarus Unit for controlling console process, with Prompt Detection.

This unit can process the standard input/output of console process, and support ANSI
escape sequences, using a virtual VT100 terminal. It includes
routines for detect the prompt, and consequently the states of BUSY and READY.

In the current version it's not supported to read the standard error stream.

For to start a process it's necessary to create an object TConsoleProc:

  p := TConsoleProc.Create(StatusBar1.Panels[1]);
  ...
  p.Free;
}
unit UnTerminal;

{$mode objfpc}{$H+}
interface
uses  Classes, SysUtils, Process, ExtCtrls, Dialogs, Graphics, ComCtrls,
     LCLProc, LCLType, TermVT, types, Strutils;
const
  UBLOCK_SIZE = 2048;    //Tamaño de bloque de lectura de salida de proceso

type
//Posibles estados de la conexión
TEstadoCon = (
   ECO_CONNECTING, //Iniciado y Conectando
   ECO_ERROR_CON,  //Iniciado y Con error de conexión
   ECO_BUSY,       //Iniciado y conectado, pero ejecutando algún proceso
   ECO_READY,      //Iniciado y conectado, libre para aceptar comandos.
   ECO_STOPPED     //Proceso no iniciado. Puede que haya datos pendientes en el "buffer"
);
//Tipos de reconocimiento del prompt en una línea
TPrompMatch = (
   prmExactly,   //prompt es la línea entera
   prmAtBegin,   //prompt aparece al inicio de la línea
   prmAtEnd,     //prompt aparece al final de la línea
   prmAtAnyPos   //prompt aparece en cualquier parte de la línea
);

//Tipo de delimitador de línea a enviar
TUtLineDelSend = (
   LDS_CRLF,   //Envía los caracteres CR y LF
   LDS_CR,     //Envía solo CR
   LDS_LF      //Envía solo LF
);
//Tipo de delimitador de línea a recibir
TUtLineDelRecv = (
   LDR_CRLF,  //El salto de línea es CR-LF (o LF-CR)
   LDR_CR,    //El salto de línea es este caracter. Se ignora LF
   LDR_LF,    //El salto de línea es este caracter. Se ignora CR
   LDR_CR_LF  //El salto de línea es este CR o LF
);

{Evento. Pasa la cantidad de bytes que llegan y la columna y fila final de la matriz Lin[] }
TEvProcState  = procedure(nDat: integer; pFinal: TPoint) of object;
TEvReadData   = procedure(nDat: integer; const lastLine: string) of object;
TEvGetPrompt  = procedure(prmLine: string; pIni: TPoint; HeightScr: integer) of object;
TEvChkForPrompt = function(const lin: string): boolean of object;
TEvLinCompleted = procedure(const lin: string) of object;
TEvRecSysComm = procedure(info: string; pIni: TPoint) of object;

TEvRefreshAll  = procedure(const grilla: TtsGrid) of object;
TEvInitScreen  = procedure(const grilla: TtsGrid; fIni, fFin: integer) of object;
TEvRefreshLine = procedure(const grilla: TtsGrid; fIni, HeightScr: integer) of object;
TEvRefreshLines= procedure(const grilla: TtsGrid; fIni, fFin, HeightScr: integer) of object;
TEvAddNewLine   = procedure(HeightScr: integer) of object;

{ TConsoleProc }
//Clase que define un proceso
TConsoleProc = class
private
  bolsa   : array[0..UBLOCK_SIZE] of char;  //buffer para almacenar salidas(tiene un caracter más)
  nLeidos : LongInt;
  lstTmp  : TStringList;

  cAnim   : integer;      //Contador para animación de ícono de estado
  angA    : integer;      //Contador para animación de ícono de estado
  procedure SetLineDelimRecv(AValue: TUtLineDelRecv);
  procedure RefreshConnection(Sender: TObject);  //Refresca la conexión
  function ChangeState(estado0: TEstadoCon): boolean;  //Cambia el State actual
private  //Auxiliar variables and methods, used by RunInLoop
  LoopList: TStringList;  //Lista de salida para cuando se usa RunInLoop().
  outList: TStringList;   //Lista de salida para cuando se usa RunInLoop().
  LinPartial: boolean;    //Bandar
  procedure ProcLoop(const lin: string);
  procedure DoLineCompleted(const lin: string);
  procedure DoReadData(nDat: integer; const lastLine: string);
protected
  panel     : TStatusPanel; //referencia a panel para nostrar estado
  curPanel  : TStatusPanel; //para nostrar posición de cursor de editor de salida
  lastState : TEstadoCon;  //Estado anterior
  txtState  : string;      //Cadena que describe el estado actual de la conexión
  clock     : TTimer;      //temporizador para leer salida del proceso
  FLineDelimSend: TUtLineDelSend;
  FLineDelimRecv: TUtLineDelRecv;
  function ContainsPrompt(const linAct: string; var pos1, pos2: integer;
    posIni: integer=1): boolean;
  function ContainsPromptL(const linAct: string; var pos1, pos2: integer
    ): boolean;
  function EsPrompt(const cad: string): boolean;
  function GetTerminalWidth: integer;
  procedure SetTerminalWidth(AValue: integer);
  function DoReadData: boolean;
  //respuesta a eventos de term
  procedure termAddLine;
  procedure termRefreshLines(fIni, fFin: integer);
  procedure termRecSysComm(info: string);
  procedure termLineCompleted(const lineCompleted: string);
public  //Events
  //Change state events.
  OnConnecting : TEvProcState;    //indica que se inicia el proceso y trata de conectar
  OnBusy       : TEvProcState;    //indica que está esperando prompt
  OnStopped    : TEvProcState;    //indica que se terminó el proceso
  OnGetPrompt  : TEvGetPrompt;   //indica que llegó el prompt
  OnChangeState: TEvRecSysComm;   //cambia de estado
  //Arriving data events.
  OnRefreshAll  : TEvRefreshAll;   //Para refrescar todo el contenido del terminal. No recomendable.
  OnInitScreen  : TEvInitScreen;   //indica que se debe agregar líneas de texto
  OnRefreshLine : TEvRefreshLine;  //indica que se deben refrescar una línea
  OnRefreshLines: TEvRefreshLines; //indica que se deben refrescar un grupo de líneas
  OnAddLine     : TEvAddNewLine;   //inidca que se debe agregar una línea a la salida
  //Optional arriving data events.
  OnLineCompleted:TEvLinCompleted; {Cuando se ha terminado de escribir una línea en el terminal.
                                   No funcionará si es que se producen saltos en el cursor}
  OnLinePrompt  : TEvLinCompleted;  //Cuando llega la línea del prompt
  //Aditional events.
  OnChkForPrompt: TEvChkForPrompt; //Permite incluir una rutina externa para verificación de prompt.
  OnFirstReady  : TEvGetPrompt;    //La primera vez que de detcta el prompt
  OnReadData    : TEvReadData;    //Cuando llega una trama de datos por el terminal
  OnRecSysComm  : TEvRecSysComm;   {indica que llegó información del sistema remoto (usuario,
                                  directorio actual, etc) Solo para conex. Telnet}
public
  //datos del proceso
  State        : TEstadoCon;    //Estado de la conexión
  ClearOnOpen  : boolean;       //Para limpiar pantalla al llamar a Open()
  p            : TProcess;      //el proceso a manejar
  //manejo del prompt
  detecPrompt: boolean;      //activa la detección de prompt.
  promptIni  : string;       //cadena inicial del prompt
  promptFin  : string;       //cadena final del prompt
  promptMatch: TPrompMatch;  //tipo de coincidencia
  HayPrompt  : boolean;      //bandera, indica si se detectó el prompt en la última línea

  msjError   : string;       //guarda el mensaje de error
  term       : TTermVT100;   //Terminal
  property LineDelimSend: TUtLineDelSend read FLineDelimSend write FLineDelimSend; //Tipo de delimitador de línea
  property LineDelimRecv: TUtLineDelRecv read FLineDelimRecv write SetLineDelimRecv; //Tipo de delimitador de línea para recibir
  procedure Start;   //inicia proceso
  procedure Open(progPath, progParam: string); //Inicia conexión
  function Close: boolean;    //Termina la conexión
  procedure ClearTerminal;
  property TerminalWidth: integer read GetTerminalWidth write SetTerminalWidth;
  procedure Send(const txt: string);
  procedure SendLn(txt: string);  //Envía datos por el "stdin"
  procedure SendFile(name: string);  //Envía el contenido de un archivo
  procedure SendVT100Key(var Key: Word; Shift: TShiftState);  //Envía una tecla con secuencia de escape
  function LastLine: string; inline; //devuelve la última línea
  procedure AutoConfigPrompt; virtual;
public //Execution without TTimer.
  function Loop(TimeoutSegs: integer = - 1; ldelay: integer = 50): boolean;
  function RunInLoop(progPath, progParam: string; TimeoutSegs: integer = -1): boolean;
  function RunInLoop(progPath, progParam: string; TimeoutSegs: integer;
    var progOut: TStringList): boolean;
  function RunInLoop(progPath, progParam: string; TimeoutSegs: integer; out
    outText: String): boolean;
public  //Statusbar control
  procedure RefStatePanel;
  procedure DrawStatePanel(c: TCanvas; const Rect: TRect); virtual;
public   //Initialization
  constructor Create(PanControl: TStatusPanel); virtual;   //Constructor
  destructor Destroy; override;   //Limpia los buffers
end;

implementation
//uses FormConfig;   //se necesita acceder a las propiedades de prompt
const
  STA_NAME_CONNEC  = 'Connecting';
  STA_NAME_ERR_CON = 'Connection Error';
  STA_NAME_BUSY    = 'Busy';
  STA_NAME_READY   = 'Ready';
  STA_NAME_STOPPED = 'Stopped';
  MSG_ERR_NO_APP_DEF = 'No Application specified for connection.';
  MSG_FAIL_START_APP = 'Fail Starting Application: ';
  MSG_NO_PRMP_FOUND  = 'Prompt Not Found for to configure in Terminal.';
  MSG_ERR_TIMEOUT = 'Timeout in process.';
{
  STA_NAME_CONNEC  = 'Conectando';
  STA_NAME_ERR_CON = 'Error en conexión';
  STA_NAME_BUSY    = 'Ocupado';
  STA_NAME_READY   = 'Disponible';
  STA_NAME_STOPPED = 'Detenido';
  MSG_ERR_NO_APP_DEF = 'No se especificó aplicativo para conexión.';
  MSG_FAIL_START_APP = 'Fallo al iniciar aplicativo: ';
  MSG_NO_PRMP_FOUND  = 'No se encuentra un prompt en el terminal para configurarlo.';
//}

function Explode(delimiter:string; str:string):TStringDynArray;
var
   p,cc,dsize:integer;
begin
   cc := 0;
   dsize := length(delimiter);
   while true do begin
     p := pos(delimiter,str);
     if p > 0 then begin
       inc(cc);
       setlength(result,cc);
       result[cc-1] := copy(str,1,p-1);
       delete(str,1,p+dsize-1);
     end else break;
   end;
   inc(cc);
   setlength(result,cc);
   result[cc-1] := str;
end;
function TConsoleProc.ChangeState(estado0: TEstadoCon): boolean;
{Cambia el estado de la conexión  y actualiza un panel con información sobre el estado}
begin
  lastState := State;  //pasa State actual a anterior
  State := estado0;    //fija State actual
  if lastState <> State then begin   //indica si hubo cambio
    //hubo cambio de State
    Result := true;
    case State of
    ECO_CONNECTING: begin
        txtState := STA_NAME_CONNEC;
        RefStatePanel;  //fuerza a redibujar panel con el nuevo State
        if OnConnecting<>nil then OnConnecting(0,term.CurXY);
      end;
    ECO_ERROR_CON: begin
        txtState := STA_NAME_ERR_CON;
        RefStatePanel;  //fuerza a redibujar panel con el nuevo State
//        if OnErrorConex <> nil then OnErrorConex(nLeidos, pErr);
      end;
    ECO_BUSY: begin
        txtState := STA_NAME_BUSY;
        RefStatePanel;  //fuerza a redibujar panel con el nuevo State
        if OnBusy <> nil then OnBusy(nLeidos, term.CurXY);
      end;
    ECO_READY: begin
        txtState := STA_NAME_READY;
        RefStatePanel;  //fuerza a redibujar panel con el nuevo State
        if OnGetPrompt <> nil then OnGetPrompt(LastLine, term.CurXY, term.height);
      end;
    ECO_STOPPED: begin
        txtState := STA_NAME_STOPPED;
        RefStatePanel;  //fuerza a redibujar panel con el nuevo State
        if OnStopped <> nil then OnStopped(nLeidos, term.CurXY);
      end;
    end;
    if OnChangeState<>nil then OnChangeState(txtState, term.CurXY);
  end;
end;
function TConsoleProc.LastLine: string; inline;
//Devuelve la línea donde se encuentra el cursor. Salvo que haya, saltos en el cursor,
//devolverá siempre los últimos caracteres recibidos.
begin
  Result := term.buf[term.CurY];
end;
function TConsoleProc.GetTerminalWidth: integer;
//Devuelve el ancho del terminal
begin
  Result := term.width;
end;
procedure TConsoleProc.SetTerminalWidth(AValue: integer);
//Fija el ancho del terminal
begin
  if term.width=AValue then Exit;
  term.width := AValue;
end;
procedure TConsoleProc.Start;
{Inicia el proceso y verifica si hubo error al lanzar el proceso. Los parámetros del
proceso, deben haberse fijado antes en el proceso.}
begin
  //ejecutamos
  ChangeState(ECO_CONNECTING);  //importante para
  try
    p.Execute;
    if not p.Running then begin
       //Falló al iniciar
       ChangeState(ECO_STOPPED);
       Exit;
    end;
    //Se inició, y esperamos a que RefreshConnection() procese los datos recibidos
  except
    if trim(p.Executable) = '' then
      msjError := MSG_ERR_NO_APP_DEF
    else
      msjError := MSG_FAIL_START_APP + p.Executable;
    ChangeState(ECO_ERROR_CON); //genera evento
  end;
end;
procedure TConsoleProc.Open(progPath, progParam: string);
//Rutina principal para iniciar un programa.
begin
  term.Clear;
  if trim(progPath) = '' then exit;  //protección
  //Inicia la salida de texto, refrescando todo el terminal
  if ClearOnOpen then ClearTerminal;
  if p.Running then p.Terminate(0);
  // Vamos a lanzar el proceso
  p.CommandLine := progPath + ' ' + progParam;
//  p.Executable := progPath;
//  p.Parameters.Clear;
//  p.Parameters.Add(progParam);

  // Definimos comportamiento de 'TProccess'. Es importante direccionar los errores.
  p.Options := [poUsePipes, poStderrToOutPut, poNoConsole];
  Start;   //puede dar error
end;
function TConsoleProc.Close: boolean;
//Cierra la conexión actual. Si hay error devuelve False.
var c: integer;
begin
  Result := true;
  //verifica el proceso
  if p.Running then p.Terminate(0);
  //espera hasta 100 mseg
  c := 0;
  while p.Running and (c<20) do begin
    sleep(5);
    inc(c);
  end;
  if c>= 20 then exit(false);  //sale con error
  //Pasa de Runnig a Not Running
  ChangeState(ECO_STOPPED);
  //Puede que quede datos en el "stdout"
  DoReadData; //lee lo que queda
end;
procedure TConsoleProc.ClearTerminal;
{Reinicia el terminal iniciando en (1,1) y limpiando la grilla}
begin
  term.Clear;   //limpia grilla y reinicia cursor
  //genera evento para reiniciar salida
  if OnInitScreen<>nil then OnInitScreen(term.buf, 1, term.height);
end;
function TConsoleProc.ContainsPrompt(const linAct: string; var pos1, pos2: integer;
         posIni: integer = 1): boolean;
//Verifica si una cadena de texto contiene al prompt, usando los valores actuales
//de promptIni y promptFin.
//Si la cadena contiene al prompt, devuelve TRUE y actualiza los valores pos1 y pos2
//que son los límites inicial y final del prompt, dentro de la cadema.
//posIni, es la posición inicial (inclusivo) desde donde se buscará.
//Si la salida del proceso va a ir a un editor con resaltador de sintaxis, esta rutina debe
//ser similar a la del resaltador para que haya sincronía en lo que se ve. No se separra esta
//rutina en otra unidad para que esta unidad no tenga dependencias y se pueda usar como
//librería. Además la detección del prompt para el proceso, es diferente de la deteción
//para un resaltador de sintaxis.
var
  lar: Integer;
begin
   Result := FALSE;   //valor por defecto
   lar := length(promptIni);
   pos1 := posEx(promptIni, linAct, posIni);
   if (lar>0) and (pos1>0) then begin
     //puede ser
     if promptFin = '' then begin
       //no hace falta validar más
       pos2:=pos1+lar-1;  //límite final
       Result := true;
       exit;    //no hace falta explorar más
     end;
     //hay que validar la existencia del fin del prompt
     pos2 :=posEx(promptFin,linAct, posIni);
     if pos2>0 then begin  //encontró
       pos2 := pos2 + length(promptFin)-1;
       Result := true;
       exit;
     end;
   end;
end;
function TConsoleProc.ContainsPromptL(const linAct: string; var pos1, pos2: integer): boolean;
//Similar a ContainsPrompt(), pero devuelve la última ocurrencia.
var
  p1,p2: Integer;
  hay: Boolean;
begin
  hay := ContainsPrompt(linAct, p1, p2, 1);
  if not hay then exit(false);  //no existe
  //existe el prompt, busca otro más adelante
  repeat
     pos1 := p1; pos2 := p2;   //guarda valores
     hay := ContainsPrompt(linAct, p1, p2, p1+1);
  until not hay;
  exit(true);  //hay valores
end;
function TConsoleProc.EsPrompt(const cad: string): boolean;
//Indica si la línea dada, es el prompt, de acuerdo a los parámetros dados. Esta función
//se pone aquí, porque aquí se tiene fácil acceso a las configuraciones del prompt.
var
  pos2: integer;
  pos1: integer;
begin
  if detecPrompt then begin  //si hay detección activa
    Result := false;
    //contiene al prompt, pero hay que ver la posición
    case promptMatch of
    prmExactly : begin
        if not ContainsPrompt(cad, pos1, pos2) then exit;
        if (pos1 = 1) and (pos2=length(cad)) then exit(true);
      end;
    prmAtBegin : begin
        if not ContainsPrompt(cad, pos1, pos2) then exit;
        if (pos1 = 1)  then exit(true);
      end;
    prmAtEnd   : begin
        if not ContainsPromptL(cad, pos1, pos2) then exit;
        if (pos2=length(cad)) then exit(true);
      end;
    prmAtAnyPos: begin
        if not ContainsPrompt(cad, pos1, pos2) then exit;
        exit(true);
      end;
    end;
  end else begin
    Result := false;
  end;
end;
function TConsoleProc.DoReadData: boolean;
{Verifica la salida del proceso. Si llegan datos los pasa a "term" y devuelve TRUE.
Lee en un solo bloque si el tamaño de los datos, es menor que UBLOCK_SIZE, en caso
contrario lee varios bloques. Actualiza "nLeidos", "HayPrompt". }
var nDis : longint;
    nBytes : LongInt;
begin
//  pIni := LeePosFin;
  Result := false;        //valor por defecto
  nLeidos := 0;
  HayPrompt := false;
  if P.Output = nil then exit;  //no hay cola
  repeat
    //vemos cuantos bytes hay "en este momento"
    nDis := P.Output.NumBytesAvailable;
    if nDis = 0 then break;  //sale del lazo
    if nDis < UBLOCK_SIZE then  begin
      //leemos solo los que hay, sino se queda esperando
      nBytes := P.Output.Read(bolsa, nDis);
      bolsa[nBytes] := #0;   //marca fin de cadena
      term.AddData(@bolsa);  //puede generar eventos
      nLeidos += nBytes;
    end else begin
      {Leemos bloque de UBLOCK_SIZE bytes. bolsa[] tiene en realidad un tamaño de
       UBLOCK_SIZE+1, así que dejará al menos un byte libre, para poner 0x00}
      nBytes := P.Output.Read(bolsa, UBLOCK_SIZE);
      bolsa[nBytes] := #0;   //marca fin de cadena
      term.AddData(@bolsa);  //puede generar eventos
      nLeidos += nBytes;
    end;
    {aquí también se puede detetar el prompt, con más posibilidad de detectar los
    posibles "Prompt" intermedios}
    Result := true;    //hay datos
  until not P.Running or (nBytes = 0);
  if not Result then exit;
  {Terminó de leer, aquí detectamos el prompt, porque es casi seguro que llegue
   al final de la trama.
  Ver si la línea actual, es realmente el prompt, es la forma más segura. Se probó
  viendo si la línea actual empezaba con el prompt, pero daba casos (sobretodo en
  conexiones lentas) en que llegaba una trama con pocos caracteres, de modo que se
  generaba el evento de llegada de prompt dos veces (tal vez más) en una misma línea}
  if OnChkForPrompt <> nil then begin
    //Hay rutina de verificación externa
    HayPrompt := OnChkForPrompt(LastLine);
  end else begin
    if EsPrompt(LastLine) then
      HayPrompt:=true;
  end;
  if OnReadData<>nil then OnReadData(nLeidos, LastLine);
  if HayPrompt then begin
    //Genera el evento. Este evento se generará siempre que se detecte el prompt en la
    //última línea sin ver el estado: El cambio de estado es otro procesamiento.
    if OnLinePrompt<>nil then OnLinePrompt(LastLine);
  end;
end;
procedure TConsoleProc.RefreshConnection(Sender: TObject);
{Refresca el estado de la conexión. Verifica si hay datos de salida del proceso, para
generar los eventos respectivos que capturan la salida. Es llamado autométicamente
por un Timer, cuando está disponible, pero en aplicaciones de consola, puede que sea
necesario llamarlo manualmente, o usar el método }
begin
  if State = ECO_STOPPED then Exit;  //No está corriendo el proceso.
  if p.Running then begin
     //Se está ejecutando
     if DoReadData then begin //actualiza "HayPrompt"
        if State in [ECO_READY, ECO_BUSY] then begin
           if HayPrompt then begin
              ChangeState(ECO_READY);
           end else begin
              ChangeState(ECO_BUSY);
           end;
        end else begin
           //Se está esperando conseguir la conexión (State = ECO_CONNECTING)
           //Puede que se detenga aquí con un mensaje de error en lugar del prompt
           if HayPrompt then begin
             //se consiguió conectar por primera vez
             if OnFirstReady<>nil then OnFirstReady('',term.CurXY, term.height);
//              State := ECO_READY;  //para que pase a ECO_BUSY
//              SendLn(COMAN_INIC); //envía comandos iniciales (lanza evento Ocupado)
             ChangeState(ECO_READY);
           end;
        end;
     end;
  end else begin //terminó
     ChangeState(ECO_STOPPED);
     DoReadData; //lee por si quedaban datos en el buffer
  end;
  //actualiza animación
  inc(cAnim);
  if (cAnim mod 4) = 0 then begin
    if State in [ECO_CONNECTING, ECO_BUSY] then begin  //estados de espera
      inc(angA);if angA>7 then angA:=0;
      RefStatePanel;
    end;
    cAnim := 0;
  end;
end;
procedure TConsoleProc.Send(const txt: string);
{Envía una cadena como como flujo de entrada al proceso.
Es importante agregar el caracter #13#10 al final. De otra forma no se leerá el "stdin"}
begin
  if p = NIL then exit;
  if not p.Running then exit;
  p.PipeBufferSize:=20000;
//  p.Input.Size:=20000;
  p.Input.Write(txt[1], length(txt));  //pasa el origen de los datos

  //Para que se genere un cambio de State aunque el comando sea muy corto
  if State = ECO_READY then ChangeState(ECO_BUSY);
end;
procedure TConsoleProc.SendLn(txt: string);
{Envía un comando al proceso. Incluye el salto de línea al final de la línea.
 También puede recibir cadneas de varias líneas}
begin
  //reemplaza todos los saltos por #1
  txt := StringReplace(txt,#13#10,#1,[rfReplaceAll]);
  txt := StringReplace(txt,#13,#1,[rfReplaceAll]);
  txt := StringReplace(txt,#10,#1,[rfReplaceAll]);
  //incluye el salto final
  txt += #1;
  //Aplica el salto configurado
  case FLineDelimSend of
  LDS_CRLF: txt := StringReplace(txt,#1,#13#10,[rfReplaceAll]); //envía CRLF
  LDS_CR  : txt := StringReplace(txt,#1,#13,[rfReplaceAll]);  //envía CR
  LDS_LF  : txt := StringReplace(txt,#1,#10,[rfReplaceAll]);  //envía LF
  end;
  Send(txt);
end;
procedure TConsoleProc.SendFile(name: string);
//Envía el contendio completo de un archivo
var lins: TstringList;
  lin: String;
begin
  lins:= TstringList.Create;
  if not FileExists(name) then exit;
  lins.LoadFromFile(name);
  for lin in lins do
    SendLn(lin);
  lins.Free;
end;
procedure TConsoleProc.SendVT100Key(var Key: Word; Shift: TShiftState);
//Envía una tecla de control (obtenida del evento KeyDown), realizando primero
//la transformación a secuencias de escapa.
begin
  case Key of
  VK_END  : begin
      if Shift = [] then Send(#27'[K');
    end;
  VK_HOME : begin
      if Shift = [] then Send(#27'[H');
    end;
  VK_LEFT : begin
      if Shift = [] then Send(#27'[D');
    end;
  VK_RIGHT: begin
      if Shift = [] then Send(#27'[C');
    end;
  VK_UP   : begin
      if Shift = [] then Send(#27'[A');
    end;
  VK_DOWN : begin
      if Shift = [] then Send(#27'[B');
    end;
  VK_F1   : begin
      if Shift = [] then Send(#27'OP');
    end;
  VK_F2   : begin
      if Shift = [] then Send(#27'OQ');
    end;
  VK_F3   : begin
      if Shift = [] then Send(#27'OR');
    end;
  VK_F4   : begin
      if Shift = [] then Send(#27'OS');
    end;
  VK_BACK : begin
      if Shift = [] then Send(#8);  //no transforma
    end;
  VK_TAB : begin
      if Shift = [] then Send(#9);  //no transforma
    end;
  VK_A..VK_Z: begin
      if Shift = [ssCtrl] then begin  //Ctrl+A, Ctrl+B, ... Ctrl+Z
        Send(chr(Key-VK_A+1));
      end;
    end;
  end;
end;
procedure TConsoleProc.ProcLoop(const lin: string);
{Método interno de respuesta al evento OnLineCompleted(), para usarse con RunInLoop()}
begin
  if LoopList<>nil then begin
    LoopList.Add(lin);   //solo acumula
  end;
end;
procedure TConsoleProc.DoLineCompleted(const lin: string);
{Método interno de respuesta al evento OnLineCompleted(), para usarse con RunInLoop()}
begin
  if LinPartial then begin
    //Estamos en la línea del prompt
    outList[outList.Count-1] := lin;  //reemplaza última línea
    LinPartial := false;
  end else begin  //caso común
    outList.Add(lin);
  end;
end;
procedure TConsoleProc.DoReadData(nDat: integer; const lastLine: string);
{Método interno de respuesta al evento OnReadData(), para usarse con RunInLoop()}
begin
  LinPartial := true;   //marca bandera
  outList.Add(lastLine);   //agrega la línea que contiene al prompt
end;
procedure TConsoleProc.SetLineDelimRecv(AValue: TUtLineDelRecv);
begin
  FLineDelimRecv:=AValue;
  case FLineDelimRecv of
  LDR_CRLF : begin term.bhvCR := tbcNormal ; term.bhvLF := tbcNormal ; end;
  LDR_CR   : begin term.bhvCR := tbcNewLine; term.bhvLF := tbcNone   ; end;
  LDR_LF   : begin term.bhvCR := tbcNone   ; term.bhvLF := tbcNewLine; end;
  LDR_CR_LF: begin term.bhvCR := tbcNewLine; term.bhvLF := tbcNewLine; end;
  end;
end;
function TConsoleProc.Loop(TimeoutSegs: integer = -1; ldelay:integer = 50): boolean;
{Ejecuta el proceso en un lazo, hasta que la aplicación termine o hasta que se
cumpla el número de segundos indicados en "TimeoutSegs". Si se detiene por desborde
devuelve TRUE, y un mensaje de error en "msjError".
"ldelay" es la duración en milisegundos que se asigna al bucle.
Se usa cuando no se puede usar el temporizador, como en las aplicaciones de consola.}
var
  tic_proc: Integer;
  max_tics: integer;
begin
  if TimeoutSegs=-1 then begin
    //ejecuta lazo hasta que termine el proceso
    repeat
      RefreshConnection(nil);
      sleep(ldelay);
    until State = ECO_STOPPED;
    exit(false);
  end else begin
    //ejecuta hasta que termine el proceso o haya desborde de tiempo
    tic_proc := 0;
    max_tics := TimeoutSegs * 20;
    repeat
      RefreshConnection(nil);  //necesario porque no funciona el Timer del LCL
      sleep(ldelay);
      inc(tic_proc);
    until (State = ECO_STOPPED) or (tic_proc > max_tics);
    if tic_proc > max_tics then begin
      msjError := MSG_ERR_TIMEOUT;
      exit(true);
    end;
    exit(false);
  end;
end;
function TConsoleProc.RunInLoop(progPath, progParam: string;
                                TimeoutSegs: integer = -1): boolean;
{Ejecuta el proceso y el lazo de espera (Loop), a la vez.
}
begin
  Open(progPath, progParam);
  if msjError<>'' then exit;
  Result := Loop(TimeoutSegs);
  //puede generar error
end;
function TConsoleProc.RunInLoop(progPath, progParam: string;
  TimeoutSegs: integer; var progOut: TStringList): boolean;
{Versión de RunInLoop(), que ejecuta captura la salida del proceso en un TString
}
begin
  OnLineCompleted:=@ProcLoop;
  LoopList := progOut;   //aquí se acumulará la salida
  Result := RunInLoop(progPath, progParam, TimeoutSegs);
  OnLineCompleted:=nil;
  //puede generar error
end;
function TConsoleProc.RunInLoop(progPath, progParam: string;
  TimeoutSegs: integer; out outText: String): boolean;
{Versión de RunInLoop(), que ejecuta captura la salida del proceso en una cadena
}
begin
  OnLineCompleted := @DoLineCompleted;
  OnReadData      := @DoReadData;
  outList := TStringList.Create;   //Aquí se acumulará la salida
  Result := RunInLoop(progPath, progParam, TimeoutSegs);
  outText := outList.Text;
  outList.Destroy;
  OnLineCompleted := nil;
  OnReadData := nil;
  //puede generar error
end;
//respuesta a eventos de term
procedure TConsoleProc.termAddLine;
//Se pide agregar líneas a la salida
begin
  if OnAddLine<>nil then OnAddLine(term.height);
end;
procedure TConsoleProc.termRefreshLines(fIni, fFin: integer);
//Se pide refrescar un rango de líneas
begin
  if OnRefreshAll<>nil then OnRefreshAll(term.buf);  //evento
  if fIni=fFin then begin  //una sola línea
    if OnRefreshLine<> nil then OnRefreshLine(term.buf, fIni, term.height);
  end else begin
    if OnRefreshLines<> nil then OnRefreshLines(term.buf, fIni, fFin, term.height);
  end;
end;
procedure TConsoleProc.termRecSysComm(info: string);
//Se ha recibido comando con información del sistema.
begin
  //se indica que se recibe información del sistema
  if OnRecSysComm<>nil then OnRecSysComm(info, term.CurXY);
  //Se puede asumir que llega el prompt pero no siempre funciona
//  HayPrompt := true;    //marca bandera
//  ChangeState(ECO_READY);  //cambia el State
end;
procedure TConsoleProc.termLineCompleted(const lineCompleted: string);
begin
  if OnLineCompleted<>nil then OnLineCompleted(lineCompleted);
end;
procedure TConsoleProc.AutoConfigPrompt;
//Configura el prompt actual como el prompt por defecto. Esta configuración no es
//para nada, precisa pero ahorrará tiempo en configurar casos sencillos
var
  ultlin: String;
  function SimbolosIniciales(cad: string): string;
  //Toma uno o dos símbolos iniciales de la cadena. Se usan símbolos porque
  //suelen ser fijos, mientras que los caracteres alfabéticos suelen cambiar
  //en el prompt.
  begin
    Result := cad[1];  //el primer caracter se tomará siempre
    if length(cad)>3 then begin
      //agrega si es un símbolo.
      if not (cad[2] in ['a'..'z','A'..'Z']) then
        Result += cad[2];
    end;
  end;
  function SimbolosFinales(cad: string): string;
  //Toma uno o dos o tres caracteres finales de la cadena. Se usan símbolos porque
  //suelen ser fijos, mientras que los caracteres alfabéticos suelen cambiar
  //en el prompt.
  var
    p: Integer;
    hayEsp: Boolean;
  begin
    p := length(cad);  //apunta al final
    hayEsp := (cad[p] = ' ');
    cad := TrimRight(cad);  //quita espacios
    if length(cad)<=2 then begin
      //hay muy pocos caracteres
      Result := cad[p-1]+cad[p];  //toma los últimos
      exit;
    end;
    //hay suficientes caracteres
    p := length(cad);  //apunta al final (sin espacios)
    Result := cad[p];
    //agrega si es un símbolo.
    if not (cad[p-1] in ['a'..'z','A'..'Z']) then
      Result := cad[p-1] + Result;
    //completa con espacio si hubiera
    if hayEsp then Result += ' ';
  end;
begin
  //utiliza la línea actual del terminal
  promptIni := '';
  promptFin := '';
  ultlin := LastLine;
  if ultlin = '' then begin
    ShowMessage(MSG_NO_PRMP_FOUND);
    exit;
  end;
  //casos particulares
  If ultlin = '>>> ' Then begin //caso especial
    DetecPrompt := true;
    promptIni := '>>';
    promptFin := ' ';
    SendLn(''); //para que detecte el prompt
    exit;
  end;
  If ultlin = 'SQL> ' Then begin //caso especial
    DetecPrompt := true;
    promptIni := 'SQL> ';
    promptFin := '';
    SendLn(''); //para que detecte el prompt
    exit;
  end;
  If length(ultlin)<=3 Then begin //caso especial
    DetecPrompt := true;
    promptIni := ultlin;
    promptFin := '';
    SendLn(''); //para que detecte el prompt
    exit;
  end;
  //caso general
  DetecPrompt := true;
  promptIni := SimbolosIniciales(ultlin);
  promptFin := SimbolosFinales(ultlin);
  SendLn(''); //para que detecte el prompt
end;
//Statusbar control
procedure TConsoleProc.RefStatePanel;   //Refresca el estado del panel del StatusBar asociado.
begin
  if panel = nil then exit;  //protección
  //fuerza a llamar al evento OnDrawPanel del StatusBar
  panel.StatusBar.InvalidatePanel(panel.Index,[ppText]);
  //y este a us vez debe llamar a DrawStatePanel()
end;
procedure TConsoleProc.DrawStatePanel(c: TCanvas; const Rect: TRect);
{Dibuja un ícono y texto, de acuerdo al estado de la conexión. Este código está pensado
 para ser usado en el evento OnDrawPanel() de una barra de estado}
var
  p1,p2: Tpoint;
  procedure Pie(c: Tcanvas; x1,y1,x2,y2: integer; a1,a2: double);  //dibuja una torta
  var x3,y3,x4,y4: integer;
      xc, yc: integer;
  begin
    xc := (x1+x2) div 2; yc := (y1+y2) div 2;
    x3:=xc + round(1000*cos(a1));
    y3:=yc + round(1000*sin(a1));
    x4:=xc + round(1000*cos(a2));
    y4:=yc + round(1000*sin(a2));
    c.pie(x1,y1,x2,y2,x3,y3,x4,y4);
  end;
  procedure Circulo(c: Tcanvas; xc,yc: integer; n: integer);  //dibuja un círculo
  const r = 2;
  begin
    case n of
    5: c.Brush.Color:=$B0FFB0;
    4: c.Brush.Color:=$40FF40;
    3: c.Brush.Color:=$00E000;
    2: c.Brush.Color:=$00CC00;
    1: c.Brush.Color:=$00A000;
    0: c.Brush.Color:=$008000;
    else
     c.Brush.Color:=clWhite;
    end;
    c.Pen.Color:=c.Brush.Color;
    c.Ellipse(xc-r, yc-r+1, xc+r, yc+r+1);
  end;
begin
  if State in [ECO_CONNECTING, ECO_BUSY] then begin  //estados de espera
    c.Pen.Width:=0;  //restaura ancho
    Circulo(c,Rect.Left+5,Rect.Top+5, angA);
    inc(angA);if angA>7 then angA:=0;
    Circulo(c,Rect.Left+9,Rect.Top+3, angA);
    inc(angA);if angA>7 then angA:=0;
    Circulo(c,Rect.Left+13,Rect.Top+5, angA);
    inc(angA);if angA>7 then angA:=0;
    Circulo(c,Rect.Left+15,Rect.Top+9, angA);
    inc(angA);if angA>7 then angA:=0;
    Circulo(c,Rect.Left+13,Rect.Top+13, angA);
    inc(angA);if angA>7 then angA:=0;
    Circulo(c,Rect.Left+9,Rect.Top+15, angA);
    inc(angA);if angA>7 then angA:=0;
    Circulo(c,Rect.Left+5,Rect.Top+13, angA);
    inc(angA);if angA>7 then angA:=0;
    Circulo(c,Rect.Left+3,Rect.Top+9, angA);
    inc(angA);if angA>7 then angA:=0;

  end else if State = ECO_ERROR_CON then begin //error de conexión
    //c´rculo rojo
    c.Brush.Color:=clRed;
    c.Pen.Color:=clRed;
    c.Ellipse(Rect.Left+2, Rect.Top+2, Rect.Left+16, Rect.Top+16);
    //aspa blanca
    c.Pen.Color:=clWhite;
    c.Pen.Width:=2;
    p1.x := Rect.Left+5; p1.y := Rect.Top+5;
    p2.x := Rect.Left+12; p2.y := Rect.Top+12;
    c.Line(p1,p2);
    p1.x := Rect.Left+5; p1.y := Rect.Top+12;
    p2.x := Rect.Left+12; p2.y := Rect.Top+5;
    c.Line(p1,p2);
  end else if State = ECO_READY then begin //disponible
    c.Brush.Color:=clGreen;
    c.Pen.Color:=clGreen;
    c.Ellipse(Rect.Left+2, Rect.Top+2,Rect.Left+16, Rect.Top+16);
    c.Pen.Color:=clWhite;
    c.Pen.Width:=2;
    p1.x := Rect.Left+6; p1.y := Rect.Top+7;
    p2.x := Rect.Left+8; p2.y := Rect.Top+12;
    c.Line(p1,p2);
    p1.x := Rect.Left+12; p1.y := Rect.Top+5;
//    p2.x := Rect.Left+12; p2.y := Rect.Top+5;
    c.Line(p2,p1);
  end else begin            //estados detenido
    //círculo gris
    c.Brush.Color:=clGray;
    c.Pen.Color:=clGray;
    c.Ellipse(Rect.Left+2, Rect.Top+2, Rect.Left+16, Rect.Top+16);
    //aspa blanca
    c.Pen.Color:=clWhite;
    c.Pen.Width:=2;
    p1.x := Rect.Left+5; p1.y := Rect.Top+5;
    p2.x := Rect.Left+12; p2.y := Rect.Top+12;
    c.Line(p1,p2);
    p1.x := Rect.Left+5; p1.y := Rect.Top+12;
    p2.x := Rect.Left+12; p2.y := Rect.Top+5;
    c.Line(p1,p2);
  end;
  c.Font.Color:=clBlack;
  c.TextRect(Rect, 19 + Rect.Left, 2 + Rect.Top, txtState);
end;
//Initialization
constructor TConsoleProc.Create(PanControl: TStatusPanel);
//Constructor
begin
  lstTmp := TStringList.Create;   //crea lista temporal
  p := TProcess.Create(nil); //Crea proceso
  ChangeState(ECO_STOPPED);  //State inicial. Genera el primer evento
  //configura temporizador
  clock := TTimer.Create(nil);
  clock.interval:=50;  {100 es un buen valor, pero para mayor velocidad de recepción, se
                        puede usar 50 milisegundos}
  clock.OnTimer := @RefreshConnection;
  panel := PanControl;  //inicia referencia a panel
  if panel<> nil then
    panel.Style:=psOwnerDraw;  //configura panel para dibujarse por evento
  detecPrompt := true;    //activa detección de prompt por defecto
  promptMatch := prmExactly;   //debe ser exacta
  ClearOnOpen := true;         //por defecto se limpia la pantalla
  //Crea y configura terminal
  term := TTermVT100.Create; //terminal
  term.OnRefreshLines:=@termRefreshLines;
  term.OnScrollLines:=@termAddLine;
  term.OnLineCompleted:=@termLineCompleted;
  term.OnRecSysComm:=@termRecSysComm; {usaremos este evento para detectar la llegada
                                      del prompt}
  //Configura delimitadores de línea iniciales
  LineDelimSend := LDS_CRLF;
  LineDelimRecv := LDR_LF;
end;
destructor TConsoleProc.Destroy;
//Destructor
begin
  term.Free;
  clock.Free;  //destruye temporizador
  //verifica el proceso
  if p.Running then p.Terminate(0);
  //libera objetos
  FreeAndNIL(p);
  lstTmp.Free;    //limpia
end;


end.

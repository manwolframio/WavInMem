function wavBytes = conversionWAV(audioData, fs)

    % ¿Está en formato PCM de 16 bits? Es lo que usarn los archivos WAV de
    % PCM.   

    % Al capturar el audio del micro se captura como muestras PCM de 16 bits [-32768, 32767],
    % Matlab lo normalizan entre [-1, 1] y lo pasa a double. Es mejor para
    % procesamiento. 
    % conversionWAV --> Lo pasa a PCM de 16 bits.(PCM no comprime, es una
    % manera de representar el audio digital sin comprimir) Es lo que la
    % API espera, y es como se construye un WAV. El WAV no entiede de
    % double. Y Whisper tampoco, espera archivos reales. 
    % datos reales PCM. 16 bits = 2 bytes. Al hacer la petición HTTP post
    % se envían de 8 bits en 8 bits, es lo que soporta. 8 bits = 1 byte. [0, 255]

    if isa(audioData, 'double') || isa(audioData, 'single')
          audioData = int16(max(min(audioData, 1), -1) * 32767); %int 16 pq es el formato WAV en memoria con el que opera matlab  
    else     
          error('audioData debe ser int16');
    end

    % Parámetros
    NumChannel  = size(audioData, 2); % 2 por ser stereo, no mono.
    NumMuestra  = size(audioData, 1); % Número de muestas por canal.
    bytesPorSeg    = fs * NumChannel * 2; % Bytes por segundo. Como son 16 bits= 2 bytes --> *2
    blockAlign  = NumChannel * 2; % Bytes por muestra de frames (todas para un instante)
    dataSize    = NumMuestra * NumChannel * 2; % Tamaño bloque de datos (audio solo) en bytes.
    riffSize    = 36 + dataSize; % En WAV PCM el header son 44 bytes: 12 de RIFF + 23 de fmt + 8 data

    % Cabecera WAV (44 bytes total)
    % Cabecera necesaria porque si envío el audio sin más, WHISPER espera
    % cabecera + datos en sí. 
    cabecera = [ ...
        uint8('RIFF'),                          ...
        typecast(uint32(riffSize),    'uint8'), ...
        uint8('WAVE'),                          ...
        uint8('fmt '),                          ...
        typecast(uint32(16),          'uint8'), ... % Subchunk1Size
        typecast(uint16(1),           'uint8'), ... % AudioFormat = PCM
        typecast(uint16(NumChannel), 'uint8'), ...
        typecast(uint32(fs),          'uint8'), ...
        typecast(uint32(bytesPorSeg),    'uint8'), ...
        typecast(uint16(blockAlign),  'uint8'), ...
        typecast(uint16(16),          'uint8'), ... % Bits por muestra (bits per sample)
        uint8('data'),                          ...
        typecast(uint32(dataSize),    'uint8')  ...
    ];

    % Audio en sí
    audioEnBytes = typecast(reshape(audioData.', [], 1), 'uint8'); % Formato necesario para enviar a la API al hacer petición web. Bytes de archivo.

   wavBytes = [cabecera, audioEnBytes'];  % Concatenación cabecera + data de manera binaria en memoria (sin escribirlop en disco, sino en ram)
end

% Whisper a través de Ffmpeg detecta qué tipo de archivo y qué parámetros tiene a partir de la
% cabecera WAV. Sin cabecera no sabría qué frecuencia (fs) tiene el audio,
% cuántos canales o cómo son las muestras PCM, etc..

% FFmpeg es un programa que lee, convierte, procesa audio y vídeo a casi
% cualquier formato. Puede escribir y leer entre wav, mp3, mp4, mov...
% Cambiar frecuencia de muestreo, canales, volumen, extraer audio de un
% vídeo, cortar, unir. Al usar WHISPER, FFmpeg está integrado ya.
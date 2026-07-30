//+------------------------------------------------------------------+
//| PawaliEA Enterprise - File utilities                              |
//+------------------------------------------------------------------+
#ifndef PAWALI_EA_UTILITIES_FILE_UTILS_MQH
#define PAWALI_EA_UTILITIES_FILE_UTILS_MQH

class CPawaliFileUtils
{
public:
   static bool EnsureDirectory(const string relativePath)
   {
      if(!FolderCreate(relativePath, FILE_COMMON))
      {
         const int err = GetLastError();
         if(err != 5019 && err != 0)
            return false;
      }
      return true;
   }

   static long GetFileSize(const string relativePath)
   {
      const int handle = FileOpen(relativePath, FILE_READ | FILE_BIN | FILE_COMMON);
      if(handle == INVALID_HANDLE)
         return -1;

      const long size = FileSize(handle);
      FileClose(handle);
      return size;
   }

   static bool AppendLine(const string relativePath, const string line)
   {
      const int handle = FileOpen(relativePath,
                                  FILE_READ | FILE_WRITE | FILE_TXT | FILE_COMMON | FILE_ANSI);
      if(handle == INVALID_HANDLE)
         return false;

      FileSeek(handle, 0, SEEK_END);
      FileWriteString(handle, line + "\n");
      FileClose(handle);
      return true;
   }

   static bool ReadAllText(const string relativePath, string &content)
   {
      content = "";
      const int handle = FileOpen(relativePath, FILE_READ | FILE_TXT | FILE_COMMON | FILE_ANSI);
      if(handle == INVALID_HANDLE)
         return false;

      while(!FileIsEnding(handle))
         content += FileReadString(handle);

      FileClose(handle);
      return true;
   }

   static bool WriteAllText(const string relativePath, const string content)
   {
      const int handle = FileOpen(relativePath,
                                  FILE_WRITE | FILE_TXT | FILE_COMMON | FILE_ANSI);
      if(handle == INVALID_HANDLE)
         return false;

      FileWriteString(handle, content);
      FileClose(handle);
      return true;
   }

   static bool RotateIfNeeded(const string relativePath, const long maxBytes)
   {
      const long size = GetFileSize(relativePath);
      if(size < 0 || size < maxBytes)
         return true;

      string content = "";
      if(!ReadAllText(relativePath, content))
         return false;

      const string archivePath = relativePath + ".1";
      WriteAllText(archivePath, content);

      string empty = "";
      return WriteAllText(relativePath, empty);
   }
};

#endif

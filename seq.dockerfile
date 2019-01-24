# docker build . -t tempworks/seq:latest -t tempworks/seq:5.0.2497 -f seq.dockerfile
# docker run -d -p 80:5341 tempworks/seq

FROM mcr.microsoft.com/windows/servercore:1809


LABEL image_version="mcr.microsoft.com/windows/servercore:1809"

COPY . /app/
 
WORKDIR /app

RUN ["msiexec", "/i", "Seq-5.0.2497.msi", "/quiet", "/norestart", "/log", "install.log"]

RUN SC create seq binPath="C:\Program Files\seq\seq.exe run --storage=C:\app\seq" start=auto

EXPOSE 5341

CMD powershell.exe -command "& {while ($true) {Get-Process -Name 'seq'; Start-Sleep 30}}"

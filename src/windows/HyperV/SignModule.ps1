# Criar certificado de teste no repositório pessoal
$cert = New-SelfSignedCertificate `
    -Type CodeSigningCert `
    -Subject "CN=MeuCertificadoPowerShell" `
    -CertStoreLocation "Cert:\CurrentUser\My"

# Listar certificados de assinatura de código no repositório pessoal
$cert = Get-ChildItem Cert:\CurrentUser\My -CodeSigningCert

# Caminho do módulo (arquivo .psm1 ou .ps1)
$modulo = "D:\OneDrive\Backup\Scripts\Settings.ps1"

# Assinar o módulo
Set-AuthenticodeSignature -FilePath $modulo -Certificate $cert.Thumbprint
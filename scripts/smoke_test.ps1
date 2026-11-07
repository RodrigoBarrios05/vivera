# Vivera: prueba de humo del backend contra Supabase.
# Uso:
#   $env:VIVERA_OWNER_EMAIL = 'dueno@ejemplo.com'
#   $env:VIVERA_OWNER_PASSWORD = '...'
#   $env:VIVERA_SECOND_EMAIL = 'miembro@ejemplo.com'
#   $env:VIVERA_SECOND_PASSWORD = '...'
#   powershell -ExecutionPolicy Bypass -File scripts/smoke_test.ps1
# También se pueden pasar -OwnerEmail, -OwnerPassword, -SecondEmail y -SecondPassword.
# Requiere que los usuarios de prueba ya existan y estén confirmados.
# No imprime tokens ni claves secretas.

param(
  [string]$OwnerEmail = $env:VIVERA_OWNER_EMAIL,
  [string]$OwnerPassword = $env:VIVERA_OWNER_PASSWORD,
  [string]$SecondEmail = $env:VIVERA_SECOND_EMAIL,
  [string]$SecondPassword = $env:VIVERA_SECOND_PASSWORD,
  [string]$OrgName = 'Vivero de prueba'
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($OwnerEmail) -or [string]::IsNullOrWhiteSpace($OwnerPassword)) {
  throw 'Definí VIVERA_OWNER_EMAIL y VIVERA_OWNER_PASSWORD (o pasá -OwnerEmail y -OwnerPassword) para ejecutar la prueba.'
}
if ([string]::IsNullOrWhiteSpace($SecondEmail) -or [string]::IsNullOrWhiteSpace($SecondPassword)) {
  throw 'Definí VIVERA_SECOND_EMAIL y VIVERA_SECOND_PASSWORD (o pasá -SecondEmail y -SecondPassword) para ejecutar la prueba.'
}

$envFile = Join-Path $PSScriptRoot '..\env.json'
if (-not (Test-Path $envFile)) {
  throw 'Falta env.json. Copiá env.example.json y completá la URL y la clave pública de Supabase.'
}
$config = Get-Content $envFile -Raw | ConvertFrom-Json
$script:baseUrl = $config.SUPABASE_URL.TrimEnd('/')
$script:apiKey = $config.SUPABASE_PUBLISHABLE_KEY
$script:utf8 = New-Object System.Text.UTF8Encoding($false)
$script:callIndex = 0
$script:failures = 0
$script:tmpDir = Join-Path $env:TEMP ('vivera_smoke_' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $script:tmpDir -Force | Out-Null

function Check {
  param([bool]$Condition, [string]$Label, [string]$Detail = '')
  if ($Condition) {
    Write-Host "[OK]   $Label" -ForegroundColor Green
  } else {
    Write-Host "[FALLA] $Label $Detail" -ForegroundColor Red
    $script:failures++
  }
}

function Invoke-Api {
  param(
    [Parameter(Mandatory = $true)][string]$Method,
    [Parameter(Mandatory = $true)][string]$Path,
    [object]$Body = $null,
    [string]$Token = $null,
    [string]$Prefer = $null
  )

  $script:callIndex++
  $responseFile = Join-Path $script:tmpDir ("resp_{0}.json" -f $script:callIndex)
  $curlArgs = @(
    '-s',
    '-o', $responseFile,
    '-w', '%{http_code}',
    '-X', $Method,
    ($script:baseUrl + $Path),
    '-H', ("apikey: " + $script:apiKey),
    '-H', 'Content-Type: application/json'
  )

  if ($Token) {
    $curlArgs += @('-H', ("Authorization: Bearer " + $Token))
  }
  if ($Prefer) {
    $curlArgs += @('-H', ("Prefer: " + $Prefer))
  }
  if ($null -ne $Body) {
    $bodyFile = Join-Path $script:tmpDir ("body_{0}.json" -f $script:callIndex)
    $json = $Body
    if ($Body -isnot [string]) {
      $json = $Body | ConvertTo-Json -Depth 12 -Compress
    }
    [System.IO.File]::WriteAllText($bodyFile, $json, $script:utf8)
    $curlArgs += @('--data-binary', ("@" + $bodyFile))
  }

  $statusText = & curl.exe @curlArgs
  $raw = ''
  if (Test-Path $responseFile) {
    $raw = [System.IO.File]::ReadAllText($responseFile)
  }

  $parsed = $null
  if ($raw) {
    try {
      $parsed = $raw | ConvertFrom-Json
    } catch {
      $parsed = $null
    }
  }

  return [PSCustomObject]@{
    Status = [int]$statusText
    Raw    = $raw
    Json   = $parsed
  }
}

function Get-Product {
  param([string]$ProductId, [string]$Token)
  $response = Invoke-Api -Method 'GET' -Path ("/rest/v1/products?select=id,name,stock,cost_cents,sale_price_cents&id=eq." + $ProductId) -Token $Token
  return @($response.Json)[0]
}

try {
  Write-Host ''
  Write-Host '=== Vivera: prueba de humo ===' -ForegroundColor Cyan

  # 1. Login del dueño.
  $signIn = Invoke-Api -Method 'POST' -Path '/auth/v1/token?grant_type=password' -Body @{
    email    = $OwnerEmail
    password = $OwnerPassword
  }
  Check ($signIn.Status -eq 200) 'Login del usuario dueño' ("status=" + $signIn.Status + " " + $signIn.Raw)
  if ($signIn.Status -ne 200) { throw 'No se pudo iniciar sesión con el usuario dueño.' }

  $ownerToken = $signIn.Json.access_token
  $ownerId = $signIn.Json.user.id

  # 2. Organización: usar la existente o crear una nueva.
  $membershipResponse = Invoke-Api -Method 'GET' -Path ("/rest/v1/organization_members?select=organization_id,role&user_id=eq." + $ownerId) -Token $ownerToken
  $memberships = @($membershipResponse.Json)

  if ($memberships.Count -gt 0) {
    $orgId = $memberships[0].organization_id
    Check ($memberships[0].role -eq 'owner') 'El usuario dueño tiene rol owner'
    Write-Host ("       Organización existente: " + $orgId)
  } else {
    $orgResponse = Invoke-Api -Method 'POST' -Path '/rest/v1/rpc/create_organization' -Token $ownerToken -Body @{
      p_name          = $OrgName
      p_currency_code = 'MXN'
      p_locale        = 'es_MX'
      p_timezone      = 'America/Mexico_City'
    }
    Check ($orgResponse.Status -eq 200) 'Crear organización' ("status=" + $orgResponse.Status + " " + $orgResponse.Raw)
    if ($orgResponse.Status -ne 200) { throw 'No se pudo crear la organización.' }
    $orgId = [string]$orgResponse.Json
    Write-Host ("       Organización creada: " + $orgId)
  }

  # 3. Datos de la organización.
  $orgResponse = Invoke-Api -Method 'GET' -Path ("/rest/v1/organizations?select=id,name,invite_code,currency_code&id=eq." + $orgId) -Token $ownerToken
  $org = @($orgResponse.Json)[0]
  Check ($null -ne $org) 'Leer la organización'
  Check ($org.currency_code -eq 'MXN') 'Moneda MXN'
  Check ([string]$org.invite_code -match '^[A-Z0-9]{8}$') 'Código de invitación de 8 caracteres' ([string]$org.invite_code)

  $categoriesResponse = Invoke-Api -Method 'GET' -Path ("/rest/v1/categories?select=id,name,sort_order&organization_id=eq." + $orgId + "&order=sort_order") -Token $ownerToken
  $categories = @($categoriesResponse.Json)
  Check ($categories.Count -eq 8) 'Categorías iniciales creadas' ("count=" + $categories.Count)

  # 4. Producto con stock inicial.
  $suffix = (Get-Date).ToString('HHmmss')
  $productName = 'Ficus de prueba ' + $suffix
  $productResponse = Invoke-Api -Method 'POST' -Path '/rest/v1/rpc/create_product' -Token $ownerToken -Body @{
    p_organization_id = $orgId
    p_name            = $productName
    p_unit            = 'pieza'
    p_sale_price_cents = 25000
    p_cost_cents      = 10000
    p_min_stock       = 2
    p_initial_stock   = 10
    p_notes           = 'Producto creado por la prueba de humo'
  }
  Check ($productResponse.Status -eq 200) 'Crear producto' ("status=" + $productResponse.Status + " " + $productResponse.Raw)
  if ($productResponse.Status -ne 200) { throw 'No se pudo crear el producto.' }

  $productId = [string]$productResponse.Json
  $product = Get-Product -ProductId $productId -Token $ownerToken
  Check ([double]$product.stock -eq 10) 'Stock inicial de 10' ("stock=" + $product.stock)
  Check ([long]$product.cost_cents -eq 10000) 'Costo inicial de $100.00' ("cost=" + $product.cost_cents)
  Check ([long]$product.sale_price_cents -eq 25000) 'Precio de venta de $250.00'

  # 5. Venta de 2 piezas.
  $saleResponse = Invoke-Api -Method 'POST' -Path '/rest/v1/rpc/create_sale' -Token $ownerToken -Body @{
    p_organization_id = $orgId
    p_payment_method  = 'efectivo'
    p_notes           = 'Venta de la prueba de humo'
    p_items           = @(
      @{ product_id = $productId; quantity = 2 }
    )
  }
  Check ($saleResponse.Status -eq 200) 'Registrar venta' ("status=" + $saleResponse.Status + " " + $saleResponse.Raw)
  if ($saleResponse.Status -ne 200) { throw 'No se pudo registrar la venta.' }

  $saleId = [string]$saleResponse.Json
  $product = Get-Product -ProductId $productId -Token $ownerToken
  Check ([double]$product.stock -eq 8) 'La venta descuenta stock (10 -> 8)' ("stock=" + $product.stock)

  # Incluye el embed de profiles para validar la relación created_by.
  $saleDetailResponse = Invoke-Api -Method 'GET' -Path ("/rest/v1/sales?select=*,profiles!sales_created_by_fkey(full_name),sale_items(*)&id=eq." + $saleId) -Token $ownerToken
  Check ($saleDetailResponse.Status -eq 200) 'Leer venta con perfil y artículos' ("status=" + $saleDetailResponse.Status + " " + $saleDetailResponse.Raw)
  $sale = @($saleDetailResponse.Json)[0]
  Check ([long]$sale.total_cents -eq 50000) 'Total de la venta $500.00' ("total=" + $sale.total_cents)
  Check ($sale.status -eq 'completed') 'Estado completed'
  Check (@($sale.sale_items).Count -eq 1) 'Un artículo en la venta'
  Check (-not [string]::IsNullOrWhiteSpace([string]$sale.profiles.full_name)) 'Nombre del creador embebido'

  # 6. Anulación de la venta.
  $cancelResponse = Invoke-Api -Method 'POST' -Path '/rest/v1/rpc/cancel_sale' -Token $ownerToken -Body @{
    p_organization_id = $orgId
    p_sale_id         = $saleId
    p_reason          = 'Prueba de anulación'
  }
  Check ($cancelResponse.Status -eq 200 -or $cancelResponse.Status -eq 204) 'Anular venta' ("status=" + $cancelResponse.Status + " " + $cancelResponse.Raw)
  $product = Get-Product -ProductId $productId -Token $ownerToken
  Check ([double]$product.stock -eq 10) 'La anulación restaura stock (8 -> 10)' ("stock=" + $product.stock)

  $cancelledSaleResponse = Invoke-Api -Method 'GET' -Path ("/rest/v1/sales?select=status,cancel_reason&id=eq." + $saleId) -Token $ownerToken
  $cancelledSale = @($cancelledSaleResponse.Json)[0]
  Check ($cancelledSale.status -eq 'cancelled') 'Estado cancelled'

  # 7. Compra de 5 piezas a $120.00.
  $purchaseResponse = Invoke-Api -Method 'POST' -Path '/rest/v1/rpc/create_purchase' -Token $ownerToken -Body @{
    p_organization_id = $orgId
    p_supplier_name   = 'Proveedor de prueba'
    p_notes           = 'Compra de la prueba de humo'
    p_items           = @(
      @{ product_id = $productId; quantity = 5; unit_cost_cents = 12000 }
    )
  }
  Check ($purchaseResponse.Status -eq 200) 'Registrar compra' ("status=" + $purchaseResponse.Status + " " + $purchaseResponse.Raw)

  $product = Get-Product -ProductId $productId -Token $ownerToken
  # (10 * 10000 + 5 * 12000) / 15 = 10666.67 -> 10667
  Check ([double]$product.stock -eq 15) 'La compra aumenta stock (10 -> 15)' ("stock=" + $product.stock)
  Check ([long]$product.cost_cents -eq 10667) 'Costo promedio ponderado $106.67' ("cost=" + $product.cost_cents)

  # 8. Ajuste de stock a 12.
  $adjustResponse = Invoke-Api -Method 'POST' -Path '/rest/v1/rpc/adjust_stock' -Token $ownerToken -Body @{
    p_organization_id = $orgId
    p_product_id      = $productId
    p_new_stock       = 12
    p_reason          = 'Conteo físico de prueba'
  }
  Check ($adjustResponse.Status -eq 200 -or $adjustResponse.Status -eq 204) 'Ajustar stock' ("status=" + $adjustResponse.Status + " " + $adjustResponse.Raw)
  $product = Get-Product -ProductId $productId -Token $ownerToken
  Check ([double]$product.stock -eq 12) 'Stock ajustado a 12' ("stock=" + $product.stock)

  # 9. Dashboard del día.
  $dayStart = (Get-Date).Date
  $dashboardResponse = Invoke-Api -Method 'POST' -Path '/rest/v1/rpc/dashboard_summary' -Token $ownerToken -Body @{
    p_organization_id = $orgId
    p_start           = $dayStart.ToUniversalTime().ToString('o')
    p_end             = $dayStart.AddDays(1).ToUniversalTime().ToString('o')
  }
  Check ($dashboardResponse.Status -eq 200) 'Consultar dashboard' ("status=" + $dashboardResponse.Status + " " + $dashboardResponse.Raw)
  $dashboard = $dashboardResponse.Json

  # El dashboard debe coincidir con el inventario actual, sin valores fijos.
  $inventoryResponse = Invoke-Api -Method 'GET' -Path ("/rest/v1/products?select=stock,cost_cents,min_stock,active&organization_id=eq." + $orgId + "&active=eq.true") -Token $ownerToken
  $inventoryItems = @($inventoryResponse.Json)
  $expectedInventory = [long]0
  $expectedLowStock = 0
  foreach ($item in $inventoryItems) {
    $expectedInventory += [long][Math]::Round([double]$item.stock * [long]$item.cost_cents, [MidpointRounding]::AwayFromZero)
    if ([double]$item.stock -le [double]$item.min_stock) {
      $expectedLowStock++
    }
  }
  Check ([long]$dashboard.inventory_value_cents -eq $expectedInventory) ('Valor de inventario calculado (' + $expectedInventory + ' centavos)') ("value=" + $dashboard.inventory_value_cents)
  Check ([long]$dashboard.low_stock_count -eq $expectedLowStock) ('Stock bajo calculado (' + $expectedLowStock + ')') ("count=" + $dashboard.low_stock_count)

  # 10. Segundo usuario: aislamiento y unión por código.
  $secondSignIn = Invoke-Api -Method 'POST' -Path '/auth/v1/token?grant_type=password' -Body @{
    email    = $SecondEmail
    password = $SecondPassword
  }
  Check ($secondSignIn.Status -eq 200) 'Login del segundo usuario' ("status=" + $secondSignIn.Status + " " + $secondSignIn.Raw)
  $secondToken = $secondSignIn.Json.access_token
  $secondId = $secondSignIn.Json.user.id

  # La prueba debe poder repetirse aunque el segundo usuario ya sea miembro.
  $membershipResponse = Invoke-Api -Method 'GET' -Path ("/rest/v1/organization_members?select=user_id&organization_id=eq." + $orgId + "&user_id=eq." + $secondId) -Token $ownerToken
  $alreadyMember = $membershipResponse.Status -eq 200 -and @($membershipResponse.Json).Count -gt 0

  if (-not $alreadyMember) {
    $beforeJoin = Invoke-Api -Method 'GET' -Path ("/rest/v1/products?select=id&organization_id=eq." + $orgId) -Token $secondToken
    Check ($beforeJoin.Status -eq 200 -and @($beforeJoin.Json).Count -eq 0) 'RLS: el segundo usuario no ve productos ajenos' ("status=" + $beforeJoin.Status)

    $forbiddenSale = Invoke-Api -Method 'POST' -Path '/rest/v1/rpc/create_sale' -Token $secondToken -Body @{
      p_organization_id = $orgId
      p_payment_method  = 'efectivo'
      p_items           = @(
        @{ product_id = $productId; quantity = 1 }
      )
    }
    Check ($forbiddenSale.Status -ne 200) 'La RPC rechaza ventas de no miembros' ("status=" + $forbiddenSale.Status)

    $joinResponse = Invoke-Api -Method 'POST' -Path '/rest/v1/rpc/join_organization' -Token $secondToken -Body @{
      p_code = [string]$org.invite_code
    }
    Check ($joinResponse.Status -eq 200 -and [string]$joinResponse.Json -eq $orgId) 'Unirse con el código de invitación' ("status=" + $joinResponse.Status + " " + $joinResponse.Raw)
  } else {
    Write-Host '       El segundo usuario ya pertenece al vivero; se omite el alta por código.' -ForegroundColor Yellow
  }

  $afterJoin = Invoke-Api -Method 'GET' -Path ("/rest/v1/products?select=id&organization_id=eq." + $orgId) -Token $secondToken
  Check ($afterJoin.Status -eq 200 -and @($afterJoin.Json).Count -ge 1) 'El segundo usuario ve el catálogo' ("count=" + @($afterJoin.Json).Count)

  Write-Host ''
  if ($script:failures -gt 0) {
    Write-Host ("RESULTADO: " + $script:failures + " comprobaciones fallaron.") -ForegroundColor Red
    exit 1
  } else {
    Write-Host 'RESULTADO: todas las comprobaciones pasaron.' -ForegroundColor Green
    exit 0
  }
} finally {
  if ($script:failures -eq 0) {
    Remove-Item -Recurse -Force $script:tmpDir -ErrorAction SilentlyContinue
  } else {
    Write-Host ("Archivos de depuración: " + $script:tmpDir) -ForegroundColor Yellow
  }
}

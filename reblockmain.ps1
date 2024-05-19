# ReBlock created by yourworstnightmare1
# GitHub: https://github.com/yourworstnightmare1/ReBlock

Write-Host "Loading..." -ForegroundColor yellow
Write-Host "Setting variables..."

# CLI Icons
$iconReBlock = "
           =============================           
         ==================================        
       ======================================      
      ========================================     
     ===========================--=============    
     =======================:........-=========    
     ======================..-======:.:========    
     =====================:.-=======+..-=======    
     =====================..=========: -=======    
     =====================..=========: -=======    
     =========::::..........:=========:========    
     =======-.               .=======+++======+    
     =====++-                 =====+++++======+    
     +++++++-                 =++++++++++++++++    
     +++++++-                 =++++++++++++++++    
     +++++++-                 =++++++++++++++++     
     +++++++-                 =++++++++++++++++    
     +++++++=.               .=++++++++++++++++    
     +++++++++--------------=++++++++++++++++++    
      ++++++++++++++++++++++++++++++++++++++++     
       ++++++++++++++++++++++++++++++++++++++      
         ++++++++++++++++++++++++++++++++++        
            ++++++++++++++++++++++++++++
"

$iconLoading = "
                 KGV                    
              MAADTZ                 
             ZLAAAAARZ               
         ZODAAAAAAAAACY              
       YIAAAABFAAAAANZ      ZOX      
     ZNAAAAJZ SAAAHX       QAAALZ    
    ZFAAAIZ   TADV         ZFAAAEZ   
   ZIAAAO     VR             OAAAHZ  
   UAAAK                      KAAAT  
   HAAC                        BAAH  
   CAAG                        HAAB  
   DAAG                        GAAC  
   LAAAX                      YAAAK  
   XBAACZ                     FAABV  
   ZOAAAG            YGR     JAAAMZ  
     RAAAAQZ       ZMAAQ   TCAAAO    
      VCABV       TCAAAPZRBAAABU     
       ZYZ      WEAAAAAAAAAAASZ      
               YHAAAAAAAADNWZ        
                 YJAAAAM             
                    NBAK
"

$iconWarning = "
                     ...                   
                    .....                  
                  ........                 
                 ....   ....               
                ....     ....              
               ......   ......             
              .......   .......            
             ........   ........           
            .........   .........          
           ..........   ..........         
          ...........   ...........        
         ............   ............       
        .............. ..............      
       ...............................     
      ...............   ...............    
     ................   ................   
    .....................................  
   .......................................
"

$iconError = "
     ####*                        *####    
   +#######-                    =#######+  
  ###########.                .###########.
   ############              ############  
     ############          ############    
      .############      ############      
        =###########*  *###########-       
          ########################         
            ####################           
              ################             
               -############:              
              ################             
            ####################           
          =######################=         
        .############  ############.       
       ############      ############      
     ############          ############    
   ############.            .############  
  ###########=                =###########.
   ########+                    *########  
     #####                        #####
"

$iconSuccess = "
                                    ===    
                                  =======  
                                ===========
                              ============ 
                             ===========   
                           ===========     
                         ===========       
     ====              ============        
   ========          ============          
  ============      ============            
  =============  ============              
    =======================                
      ===================                  
        ===============                    
          ===========                      
            ========                       
              ==== 
"

Write-Host "Getting version info..."

# ReBlock Info
$appname = "ReBlock"
$packagename = "com.reblockprojections.main.01"
$version = "v1.0w-dev"
$build = "7"
$compliationdate = "2024/5/10 @ 8:00:20 PM CDT"
$interface = "CLI"
$shell = "powershell (ps)"

Write-Host "Completed loading. Beam me up, console!" -ForegroundColor green
Clear-Host

Write-Host "$iconReBlock" -ForegroundColor red
Write-Host "Welcome to ReBlock!" -ForegroundColor red
Write-Host "Version: $version | Build: $build" -ForegroundColor yellow
Write-Host "Created & Programmed by yourworstnightmare1"

$Title = "Select any option to continue."
$Prompt = "Press the key correlating to the letter next to the option to choose it."
$Choices = [System.Management.Automation.Host.ChoiceDescription[]] @("&Tool Select", "&Exit")
$Default = 0

# Prompt for the choice
$Choice = $host.UI.PromptForChoice($Title, $Prompt, $Choices, $Default)

# Action based on the choice
switch($Choice)
{
    0 {
        Clear-Host
        Write-Host "TOOL SELECT" -ForegroundColor yellow
        Write-Host "_______________________________________________________________________________________________________" -BackgroundColor Red -ForegroundColor Red
        Write-Host "1 | ReBlock for Windows      | v1.0w   | The main application for ReBlock | ps, batch"
        Write-Host "2 | appUnblocker for Windows | v2.0w   | Unblock executable applications with UAC prompt | batch"
        Write-Host "________________________________________________________________________________________________________" -BackgroundColor Red -ForegroundColor Red

        $Title = "Select any option to continue."
        $Prompt = "Press the key correlating to the number next to the option to choose it."
        $Choices = [System.Management.Automation.Host.ChoiceDescription[]] @("&1", "&2")
        $Default = 0

        # Prompt for the choice
        $Choice = $host.UI.PromptForChoice($Title, $Prompt, $Choices, $Default)

        # Action based on the choice
        switch($Choice)
        {
        0 {
            Write-Host "Starting ReBlock for Windows, please wait..." -ForegroundColor yellow
            Write-Host "$iconLoading" -ForegroundColor yellow
            Start-Process reblockmain.exe
            Exit-PSSession
        }
        1 {
            Write-Host "Starting appUnblocker for Windows, please wait..." -ForegroundColor yellow
            Write-Host "$iconLoading" -ForegroundColor yellow
            Set-Location .
            Start-Process plugins/reblock/appunblocker/v2.0w/appunblocker.exe
            Exit-PSSession   
       }


    }
  }
}        

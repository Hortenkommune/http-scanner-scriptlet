# http-scanner-scriptlet

Scriptlet to test that any website of yours, accessible by domain or IP subnet, redirect to HTTPS-sites.  
If not, it'll warn you or give you the HTTP status code.   
Domains are automatically grabbed from Domeneshop API, so you don't have to remember adding new domains to this script.  
Creator: Alexander Hatlen for Horten Kommune.  
Copyright: none!  

USAGE:  
Set config params in ps1-file  
Edit .domeneshop-api to include you domeneshop API key ( https://api.domeneshop.no/docs )  
Run scriptfile interactively. Notice variables in bottom, they'll hold the results if you need to re-access them. Results will also be printed directly when completed.

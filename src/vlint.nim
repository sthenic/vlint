when is_main_module:
   include ./vlintpkg/private/app
else:
   import ./vlintpkg/private/analyze
   export analyze

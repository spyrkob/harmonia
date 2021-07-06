#!/bin/bash

mv workdir cts-8-mods

zip -r mods.zip cts-8-mods -x "*/.git/*"

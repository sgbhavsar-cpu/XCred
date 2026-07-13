## Resolved (2026-07-12)

1. ~~Credential attachment should show the file name.~~ Fixed — attachment list now decrypts
   and displays the real filename on load.
2. ~~Credential attachment should download original filename and not attachment.txt~~ Fixed —
   the decrypted MIME type is now passed to the download Blob so the browser preserves the
   original extension.
9. ~~Add Network device credential with multiple IP and type=web|telnet|XXX~~ Done — new
   `NetworkDevice` credential type with a repeatable IP-address list field. See
   `docs/credential-types.md`.
10. ~~whenever url, try to validate url and open url directly from the application.~~ Done —
    `url`-type fields are format-validated and have an "open in new tab" action.
18. ~~url - recovery email and recovery mobile number field as standard.~~ Done — Website
    Login and Email Account types now carry optional recovery email/phone fields.
19. ~~Bank account - Bank name, Account no, customer id, website login id, web login password,
    web transaction password, mobile login, mobile transaction~~ Done via two new types
    (`BankAccount`, `MobileBankingPin`) plus the new **Credential Groups** feature, which lets
    a "Bank" group tie the account, cards, netbanking login, and mobile PIN credentials
    together as one unit. See requirements.md §5.4.

22. FluentValidation is referenced in the API project and in requirements.md §16 but has no
    validators and is never wired into the request pipeline (`Program.cs` has no
    `AddFluentValidationAutoValidation()`/`AddValidatorsFromAssembly()` call). Either add real
    validators + wire auto-validation, or drop the unused package reference and update
    requirements.md to say validation is manual/inline (current reality).

## Still open (future work, not in this round)

3. Top level folder should filter all the child level folder credentials.
4. Use of group is not clear, Same group user should be able to see credential without sharing.
5. Or credential should be able to share with groups
6. Folder should be able to shared to multiple groups
7. Multiple credential should be able to shared to multiple groups
8. Add icon for chaning height of folder, group and tags grid rows like compact, normal, roomy.
11. User profile with photo.
12. Add authentication by Microsoft entra id
13. Filter in audit trail for user, date, ip address by direct link on value.
14. Configuration to keep audit trail in settings.
15. First page dashboard - Click on card to open that.
16. Fav implementation and display the fav on dashboard page.
17. Add filter by folder or tags on top of credential page.
20. Common search should search from notes or any other field. If required we can implement elastic search if available on pc.
21.


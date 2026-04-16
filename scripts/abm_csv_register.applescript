(***
Apple Business Manager CSV自動登録スクリプト (Safari向け)

前提:
- macOSでSafariの「開発」メニューを有効にし、JavaScript実行が許可されていること
- システム設定 > プライバシーとセキュリティ > オートメーション で、Script Editor(またはosascript)からSafari制御を許可すること
- Apple Business Managerへログイン済みで、ユーザー作成フォームを開けること

使い方:
1) scriptConfig内のCSSセレクタを、実際のABM画面DOMに合わせて調整
2) スクリプト実行後、CSVファイルを選択
3) Safariの最前面タブをABMのユーザー作成フォームにしてOK
4) CSVの各行を順次フォームへ入力して保存

CSVヘッダー例:
first_name,last_name,email,managed_apple_id,role,location,department,job_title
*** )

property scriptConfig : {¬
	inputSelectors:{¬
		first_name:"input[name='firstName']", ¬
		last_name:"input[name='lastName']", ¬
		email:"input[name='email']", ¬
		managed_apple_id:"input[name='managedAppleId']", ¬
		role:"select[name='role']", ¬
		location:"select[name='location']", ¬
		department:"input[name='department']", ¬
		job_title:"input[name='jobTitle']"}, ¬
	saveButtonSelector:"button[data-testid='save-user']", ¬
	successWaitSeconds:2.0, ¬
	rowIntervalSeconds:0.8}

on run
	set csvPath to choose file with prompt "Apple Business Manager用CSVを選択してください"
	set csvText to read csvPath as «class utf8»
	set recordsList to my parseCSV(csvText)
	if (count of recordsList) < 2 then error "CSVにヘッダーまたはデータ行が不足しています。"

	set headerRow to item 1 of recordsList
	set dataRows to items 2 thru -1 of recordsList
	set headersNorm to my normalizeHeaderRow(headerRow)

	set missingHeaders to my validateHeaders(headersNorm, {"first_name", "last_name", "email", "managed_apple_id"})
	if (count of missingHeaders) > 0 then error "必須ヘッダー不足: " & (my joinList(missingHeaders, ", "))

	display dialog "SafariでApple Business Managerのユーザー作成フォームを開いた状態で『続ける』を押してください。\n\n処理件数: " & (count of dataRows) buttons {"キャンセル", "続ける"} default button "続ける"

	repeat with rowData in dataRows
		set kvPairs to my rowToPairs(headersNorm, rowData)
		my applyRecordToABM(kvPairs)
		delay (rowIntervalSeconds of scriptConfig)
	end repeat

	display notification "CSV登録処理が完了しました" with title "ABM自動登録"
	display dialog "完了: " & (count of dataRows) & " 件" buttons {"OK"} default button "OK"
end run

on applyRecordToABM(kvPairs)
	set jsSource to my buildInjectionJavaScript(kvPairs)
	tell application "Safari"
		if not (exists front document) then error "Safariの前面タブが見つかりません。"
		do JavaScript jsSource in current tab of front window
	end tell
	delay (successWaitSeconds of scriptConfig)
end applyRecordToABM

on buildInjectionJavaScript(kvPairs)
	set saveSel to saveButtonSelector of scriptConfig

	set payloadPairs to {}
	repeat with kv in kvPairs
		set keyName to keyName of kv
		set fieldValue to valueText of kv
		set selectorValue to my selectorForKey(keyName)
		if selectorValue is not "" then
			set end of payloadPairs to "\"" & keyName & "\":{selector:\"" & (my escapeJS(selectorValue)) & "\",value:\"" & (my escapeJS(fieldValue)) & "\"}"
		end if
	end repeat

	set js to "(() => {" & ¬
		"const payload={" & (my joinList(payloadPairs, ",")) & "};" & ¬
		"const setField=(selector,value)=>{" & ¬
		"if(!selector)return; const el=document.querySelector(selector); if(!el)return;" & ¬
		"el.focus();" & ¬
		"if(el.tagName==='SELECT'){" & ¬
		"const opt=[...el.options].find(o=>o.text.trim()===value||o.value===value); if(opt){el.value=opt.value;}" & ¬
		"} else {el.value=value;}" & ¬
		"el.dispatchEvent(new Event('input',{bubbles:true}));" & ¬
		"el.dispatchEvent(new Event('change',{bubbles:true}));" & ¬
		"};" & ¬
		"Object.keys(payload).forEach(k=>setField(payload[k].selector,payload[k].value));" & ¬
		"const saveBtn=document.querySelector('" & (my escapeJS(saveSel)) & "');" & ¬
		"if(saveBtn){saveBtn.click();}" & ¬
		"})();"

	return js
end buildInjectionJavaScript

on selectorForKey(keyName)
	set selectors to inputSelectors of scriptConfig
	if keyName is "first_name" then return first_name of selectors
	if keyName is "last_name" then return last_name of selectors
	if keyName is "email" then return email of selectors
	if keyName is "managed_apple_id" then return managed_apple_id of selectors
	if keyName is "role" then return role of selectors
	if keyName is "location" then return location of selectors
	if keyName is "department" then return department of selectors
	if keyName is "job_title" then return job_title of selectors
	return ""
end selectorForKey

on normalizeHeaderRow(headerRow)
	set norm to {}
	repeat with h in headerRow
		set end of norm to my normalizeHeader(contents of h)
	end repeat
	return norm
end normalizeHeaderRow

on normalizeHeader(h)
	set t to my trimText(h)
	set t to my replaceText(" ", "_", t)
	set t to my replaceText("-", "_", t)
	set t to do shell script "python3 - <<'PY'\nimport sys\nprint(sys.stdin.read().strip().lower())\nPY" input t
	return t
end normalizeHeader

on validateHeaders(headersNorm, requiredHeaders)
	set missing to {}
	repeat with req in requiredHeaders
		if headersNorm does not contain req then set end of missing to req
	end repeat
	return missing
end validateHeaders

on rowToPairs(headersNorm, rowData)
	set pairs to {}
	set maxCol to count of headersNorm
	repeat with i from 1 to maxCol
		set keyName to item i of headersNorm
		set v to ""
		if i ≤ (count of rowData) then set v to item i of rowData
		set end of pairs to {keyName:keyName, valueText:v}
	end repeat
	return pairs
end rowToPairs

on parseCSV(csvText)
	set oldTID to AppleScript's text item delimiters
	set rowsRaw to paragraphs of csvText
	set parsed to {}
	repeat with r in rowsRaw
		if (my trimText(contents of r)) is not "" then set end of parsed to my parseCSVLine(contents of r)
	end repeat
	set AppleScript's text item delimiters to oldTID
	return parsed
end parseCSV

on parseCSVLine(lineText)
	set chars to characters of lineText
	set resultFields to {}
	set currentField to ""
	set inQuotes to false
	set i to 1
	repeat while i ≤ (count of chars)
		set c to item i of chars
		if c is "\"" then
			if inQuotes and i < (count of chars) and item (i + 1) of chars is "\"" then
				set currentField to currentField & "\""
				set i to i + 1
			else
				set inQuotes to not inQuotes
			end if
		else if c is "," and inQuotes is false then
			set end of resultFields to currentField
			set currentField to ""
		else
			set currentField to currentField & c
		end if
		set i to i + 1
	end repeat
	set end of resultFields to currentField
	return resultFields
end parseCSVLine

on joinList(aList, delim)
	set oldTID to AppleScript's text item delimiters
	set AppleScript's text item delimiters to delim
	set t to aList as text
	set AppleScript's text item delimiters to oldTID
	return t
end joinList

on trimText(t)
	set t to t as text
	repeat while t begins with space or t begins with tab or t begins with return or t begins with linefeed
		set t to text 2 thru -1 of t
		if t is "" then exit repeat
	end repeat
	repeat while t ends with space or t ends with tab or t ends with return or t ends with linefeed
		set t to text 1 thru -2 of t
		if t is "" then exit repeat
	end repeat
	return t
end trimText

on replaceText(findText, replaceWith, sourceText)
	set oldTID to AppleScript's text item delimiters
	set AppleScript's text item delimiters to findText
	set sourceItems to every text item of sourceText
	set AppleScript's text item delimiters to replaceWith
	set newText to sourceItems as text
	set AppleScript's text item delimiters to oldTID
	return newText
end replaceText

on escapeJS(t)
	set t to my replaceText("\\", "\\\\", t)
	set t to my replaceText("\"", "\\\"", t)
	set t to my replaceText(return, "\\n", t)
	set t to my replaceText(linefeed, "\\n", t)
	return t
end escapeJS

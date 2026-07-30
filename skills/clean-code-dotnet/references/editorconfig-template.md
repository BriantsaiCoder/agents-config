# .editorconfig Template for .NET Projects

Copy this to your project root as `.editorconfig`.

```ini
root = true

[*.cs]
indent_style = space
indent_size = 4
charset = utf-8
end_of_line = crlf
insert_final_newline = true

[*.md]
indent_style = space
indent_size = 2
trim_trailing_whitespace = false
# EditorConfig is awesome: https://EditorConfig.org

# 頂層 EditorConfig 檔案
root = true

# ========================================
# 所有檔案的通用設定
# ========================================
[*]
charset = utf-8
insert_final_newline = true
trim_trailing_whitespace = true
end_of_line = lf

# ========================================
# C# 專案檔案
# ========================================
[*.{csproj,props,targets}]
indent_style = space
indent_size = 2

# ========================================
# C# 原始碼檔案
# ========================================
[*.cs]
indent_style = space
indent_size = 4
tab_width = 4

# C# 程式碼樣式規則

# 'this.' 和 'Me.' 偏好設定
dotnet_style_qualification_for_field = false:suggestion
dotnet_style_qualification_for_property = false:suggestion
dotnet_style_qualification_for_method = false:suggestion
dotnet_style_qualification_for_event = false:suggestion

# 語言關鍵字與 BCL 類型偏好設定
dotnet_style_predefined_type_for_locals_parameters_members = true:warning
dotnet_style_predefined_type_for_member_access = true:warning

# 修飾詞偏好設定
dotnet_style_require_accessibility_modifiers = always:warning
dotnet_style_readonly_field = true:warning
csharp_preferred_modifier_order = public,private,protected,internal,static,extern,new,virtual,abstract,sealed,override,readonly,unsafe,volatile,async:suggestion

# 括號偏好設定
dotnet_style_parentheses_in_arithmetic_binary_operators = never_if_unnecessary:suggestion
dotnet_style_parentheses_in_relational_binary_operators = never_if_unnecessary:suggestion
dotnet_style_parentheses_in_other_binary_operators = never_if_unnecessary:suggestion
dotnet_style_parentheses_in_other_operators = never_if_unnecessary:suggestion

# 運算式層級偏好設定
dotnet_style_object_initializer = true:suggestion
dotnet_style_collection_initializer = true:suggestion
dotnet_style_explicit_tuple_names = true:warning
dotnet_style_prefer_inferred_tuple_names = true:suggestion
dotnet_style_prefer_inferred_anonymous_type_member_names = true:suggestion
dotnet_style_prefer_auto_properties = true:suggestion
dotnet_style_prefer_conditional_expression_over_assignment = false:suggestion
dotnet_style_prefer_conditional_expression_over_return = false:suggestion
dotnet_style_prefer_compound_assignment = true:suggestion
dotnet_style_prefer_simplified_interpolation = true:suggestion
dotnet_style_prefer_simplified_boolean_expressions = true:suggestion

# Null 檢查偏好設定
dotnet_style_coalesce_expression = true:warning
dotnet_style_null_propagation = true:warning
dotnet_style_prefer_is_null_check_over_reference_equality_method = true:warning

# 'var' 偏好設定
csharp_style_var_for_built_in_types = false:suggestion
csharp_style_var_when_type_is_apparent = true:suggestion
csharp_style_var_elsewhere = false:suggestion

# 運算式主體成員
csharp_style_expression_bodied_methods = false:suggestion
csharp_style_expression_bodied_constructors = false:suggestion
csharp_style_expression_bodied_operators = false:suggestion
csharp_style_expression_bodied_properties = true:suggestion
csharp_style_expression_bodied_indexers = true:suggestion
csharp_style_expression_bodied_accessors = true:suggestion
csharp_style_expression_bodied_lambdas = true:suggestion
csharp_style_expression_bodied_local_functions = false:suggestion

# 模式比對偏好設定
csharp_style_pattern_matching_over_is_with_cast_check = true:warning
csharp_style_pattern_matching_over_as_with_null_check = true:warning
csharp_style_prefer_switch_expression = true:suggestion
csharp_style_prefer_pattern_matching = true:suggestion
csharp_style_prefer_not_pattern = true:suggestion

# Null 檢查偏好設定
csharp_style_throw_expression = true:suggestion
csharp_style_prefer_null_check_over_type_check = true:suggestion
csharp_style_conditional_delegate_call = true:warning

# 程式碼區塊偏好設定
csharp_prefer_braces = true:warning
csharp_prefer_simple_using_statement = true:suggestion

# 'using' 指示詞偏好設定
csharp_using_directive_placement = outside_namespace:warning

# C# 格式規則

# 換行偏好設定
csharp_new_line_before_open_brace = all
csharp_new_line_before_else = true
csharp_new_line_before_catch = true
csharp_new_line_before_finally = true
csharp_new_line_before_members_in_object_initializers = true
csharp_new_line_before_members_in_anonymous_types = true
csharp_new_line_between_query_expression_clauses = true

# 縮排偏好設定
csharp_indent_case_contents = true
csharp_indent_switch_labels = true
csharp_indent_labels = no_change
csharp_indent_block_contents = true
csharp_indent_braces = false
csharp_indent_case_contents_when_block = false

# 空格偏好設定
csharp_space_after_cast = false
csharp_space_after_keywords_in_control_flow_statements = true
csharp_space_between_parentheses = false
csharp_space_before_colon_in_inheritance_clause = true
csharp_space_after_colon_in_inheritance_clause = true
csharp_space_around_binary_operators = before_and_after
csharp_space_between_method_declaration_parameter_list_parentheses = false
csharp_space_between_method_declaration_empty_parameter_list_parentheses = false
csharp_space_between_method_declaration_name_and_open_parenthesis = false
csharp_space_between_method_call_parameter_list_parentheses = false
csharp_space_between_method_call_empty_parameter_list_parentheses = false
csharp_space_between_method_call_name_and_opening_parenthesis = false
csharp_space_after_comma = true
csharp_space_after_dot = false
csharp_space_after_semicolon_in_for_statement = true
csharp_space_before_semicolon_in_for_statement = false
csharp_space_around_declaration_statements = false
csharp_space_before_open_square_brackets = false
csharp_space_between_empty_square_brackets = false
csharp_space_between_square_brackets = false

# 換行偏好設定
csharp_preserve_single_line_statements = false
csharp_preserve_single_line_blocks = true

# C# 命名規則

# 命名規則：介面應以 I 開頭
dotnet_naming_rule.interface_should_be_begins_with_i.severity = warning
dotnet_naming_rule.interface_should_be_begins_with_i.symbols = interface
dotnet_naming_rule.interface_should_be_begins_with_i.style = begins_with_i

# 命名規則：類型應使用 PascalCase
dotnet_naming_rule.types_should_be_pascal_case.severity = warning
dotnet_naming_rule.types_should_be_pascal_case.symbols = types
dotnet_naming_rule.types_should_be_pascal_case.style = pascal_case

# 命名規則：非欄位成員應使用 PascalCase
dotnet_naming_rule.non_field_members_should_be_pascal_case.severity = warning
dotnet_naming_rule.non_field_members_should_be_pascal_case.symbols = non_field_members
dotnet_naming_rule.non_field_members_should_be_pascal_case.style = pascal_case

# 命名規則：私有欄位應以底線開頭
dotnet_naming_rule.private_fields_should_be_underscore_camel_case.severity = warning
dotnet_naming_rule.private_fields_should_be_underscore_camel_case.symbols = private_fields
dotnet_naming_rule.private_fields_should_be_underscore_camel_case.style = underscore_camel_case

# 命名規則：常數應使用 PascalCase
dotnet_naming_rule.constants_should_be_pascal_case.severity = warning
dotnet_naming_rule.constants_should_be_pascal_case.symbols = constants
dotnet_naming_rule.constants_should_be_pascal_case.style = pascal_case

# 符號規格
dotnet_naming_symbols.interface.applicable_kinds = interface
dotnet_naming_symbols.interface.applicable_accessibilities = public, internal, private, protected, protected_internal, private_protected
dotnet_naming_symbols.interface.required_modifiers =

dotnet_naming_symbols.types.applicable_kinds = class, struct, interface, enum
dotnet_naming_symbols.types.applicable_accessibilities = public, internal, private, protected, protected_internal, private_protected
dotnet_naming_symbols.types.required_modifiers =

dotnet_naming_symbols.non_field_members.applicable_kinds = property, event, method
dotnet_naming_symbols.non_field_members.applicable_accessibilities = public, internal, private, protected, protected_internal, private_protected
dotnet_naming_symbols.non_field_members.required_modifiers =

dotnet_naming_symbols.private_fields.applicable_kinds = field
dotnet_naming_symbols.private_fields.applicable_accessibilities = private, protected, private_protected
dotnet_naming_symbols.private_fields.required_modifiers =

dotnet_naming_symbols.constants.applicable_kinds = field, local
dotnet_naming_symbols.constants.applicable_accessibilities = *
dotnet_naming_symbols.constants.required_modifiers = const

# 命名樣式
dotnet_naming_style.begins_with_i.required_prefix = I
dotnet_naming_style.begins_with_i.required_suffix =
dotnet_naming_style.begins_with_i.word_separator =
dotnet_naming_style.begins_with_i.capitalization = pascal_case

dotnet_naming_style.pascal_case.required_prefix =
dotnet_naming_style.pascal_case.required_suffix =
dotnet_naming_style.pascal_case.word_separator =
dotnet_naming_style.pascal_case.capitalization = pascal_case

dotnet_naming_style.underscore_camel_case.required_prefix = _
dotnet_naming_style.underscore_camel_case.required_suffix =
dotnet_naming_style.underscore_camel_case.word_separator =
dotnet_naming_style.underscore_camel_case.capitalization = camel_case

# ========================================
# JSON 配置檔案
# ========================================
[*.json]
indent_style = space
indent_size = 2

# ========================================
# XML 專案檔案、配置檔案
# ========================================
[*.{xml,config,nuspec,resx}]
indent_style = space
indent_size = 2

# ========================================
# Markdown 檔案
# ========================================
[*.md]
trim_trailing_whitespace = false
indent_style = space
indent_size = 2

# ========================================
# YAML 檔案 (Azure Pipelines, GitHub Actions)
# ========================================
[*.{yml,yaml}]
indent_style = space
indent_size = 2

# ========================================
# PowerShell 腳本
# ========================================
[*.{ps1,psm1,psd1}]
indent_style = space
indent_size = 4
charset = utf-8-bom

# ========================================
# Shell 腳本
# ========================================
[*.sh]
indent_style = space
indent_size = 2
end_of_line = lf

# ========================================
# Dockerfile
# ========================================
[Dockerfile]
indent_style = space
indent_size = 2

# ========================================
# SQL 檔案
# ========================================
[*.sql]
indent_style = space
indent_size = 4

# ========================================
# HTML、CSS、JavaScript
# ========================================
[*.html]
indent_style = space
indent_size = 2

[*.css]
indent_style = space
indent_size = 2

[*.{js,jsx,ts,tsx}]
indent_style = space
indent_size = 2

```

## Key Rules Explained

| Rule | Value | Reason |
|------|-------|--------|
| `_camelCase` for private fields | `_name` | Easy to distinguish from parameters |
| `PascalCase` for constants | `MaxRetries` | Consistent with C# conventions |
| No `this.` qualification | `false` | Redundant in most cases |
| System usings first | `true` | Consistent ordering |
| Braces on new line | `all` | Allman style (common in C#) |

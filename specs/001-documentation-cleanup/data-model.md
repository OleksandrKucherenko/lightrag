# Data Model: Documentation Cleanup

## Core Entities

### DocumentationFile
**Purpose**: Represents individual documentation files in the system

**Attributes**:
- `file_path`: Absolute path to the documentation file
- `file_name`: Name of the documentation file
- `content_type`: Type of content (setup, configuration, testing, etc.)
- `importance_level`: Critical, Important, or Supporting
- `consolidation_status`: Not Started, Extracted, Consolidated, Deprecated
- `target_location`: Where content should be placed in consolidated README

**Relationships**:
- Contains multiple `DocumentationSection` entities
- Belongs to a `DocumentationCategory`

### DocumentationSection
**Purpose**: Represents logical sections within documentation files

**Attributes**:
- `section_title`: Title of the section
- `section_content`: Extracted content from the section
- `importance_rating`: High, Medium, or Low
- `consolidation_target`: README section where this should be placed
- `requires_preservation`: Boolean indicating if section must be preserved

**Relationships**:
- Belongs to a `DocumentationFile`
- Maps to a `README_Section`

### README_Section
**Purpose**: Represents sections in the consolidated README.md

**Attributes**:
- `section_name`: Name of the README section
- `section_order`: Order in which section appears in README
- `content_sources`: List of documentation files that contribute to this section
- `section_content`: Consolidated content for the section

**Relationships**:
- Contains multiple `DocumentationSection` entities
- Part of the main `README` document

### DocumentationCategory
**Purpose**: Groups related documentation files by topic

**Attributes**:
- `category_name`: Name of the category (e.g., "Testing", "Performance", "Setup")
- `category_description`: Description of what this category covers
- `consolidation_priority`: Priority for consolidation (High, Medium, Low)

**Relationships**:
- Contains multiple `DocumentationFile` entities

## State Transitions

### DocumentationFile Lifecycle
1. **Initial State**: `consolidation_status = Not Started`
2. **Analysis State**: Content reviewed and sections identified
3. **Extraction State**: Important information extracted to `DocumentationSection` entities
4. **Consolidation State**: Content integrated into appropriate `README_Section`
5. **Final States**:
   - `consolidation_status = Consolidated` (if all content moved to README)
   - `consolidation_status = Deprecated` (if file moved to .deprecated/)

### README_Section Development
1. **Planning State**: Section structure defined based on consolidation requirements
2. **Content Gathering State**: Relevant `DocumentationSection` entities identified and mapped
3. **Draft State**: Initial consolidated content created
4. **Review State**: Content reviewed for accuracy and completeness
5. **Final State**: Section content finalized and integrated into README.md

## Validation Rules

### DocumentationFile Rules
- Must have unique `file_path` within the system
- Must have at least one `DocumentationSection`
- `importance_level` must be one of: Critical, Important, Supporting
- If `consolidation_status = Deprecated`, file must be moved to .deprecated/

### DocumentationSection Rules
- Must belong to exactly one `DocumentationFile`
- Must have non-empty `section_content`
- `importance_rating` must be one of: High, Medium, Low
- Must map to exactly one `README_Section`

### README_Section Rules
- Must have unique `section_name` within README
- Must have `section_order` >= 1
- Must have at least one source `DocumentationSection`
- Content must be properly formatted as markdown

## Integration Points

### File System Integration
- All `DocumentationFile` entities correspond to actual files in the repository
- File operations must maintain existing permissions and metadata
- Deprecated files must be moved to `.deprecated/` directory structure

### README Integration
- `README_Section` entities become actual sections in README.md
- Section order determines the structure of the consolidated README
- Content must be properly formatted and linked

### Verification Integration
- Data model supports comprehensive validation of consolidation process
- Enables automated verification scripts to check completeness
- Provides traceability from source documentation to consolidated content

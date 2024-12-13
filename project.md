# Civicus Project Structure

## Overview
A Phoenix LiveView application for processing and displaying Australian Federal Government YouTube content with interactive transcripts and chapter-based navigation.

## Database Schema Updates

### Inquiry Schema Additions
```elixir
# Add to existing schema in inquiry.ex
field :chapters, {:array, :map}  # Array of chapter maps
field :speaker_mappings, :map    # Map of speaker IDs to real names
```

Chapter structure:
```elixir
%{
  name: string,
  slug: string,
  start_time: integer,  # seconds
  end_time: integer,    # seconds
  summary: string
}
```

## Component Structure

### Core Components

1. `InquiryInterface` (LiveView)
   - Main container for all components
   - Manages state and coordinates component interactions
   - Handles chapter creation/editing
   - Manages speaker identification updates

2. `VideoPlayer` (LiveComponent)
   - Wraps YouTube iframe API
   - Handles video playback controls
   - Emits time update events

3. `TranscriptTimeline` (LiveComponent)
   - Visual representation of speaker segments
   - Hover tooltips showing speaker and timestamp
   - Click-to-seek functionality
   - Color coding by speaker

4. `SpeakerEditor` (LiveComponent)
   - Interface for mapping speaker IDs to real names
   - Updates speaker_mappings in real-time
   - Validates and saves speaker information

5. `ChapterManager` (LiveComponent)
   - Interface for creating/editing chapters
   - Timeline markers for chapter boundaries
   - Chapter list with edit/delete functionality

6. `TranscriptView` (LiveComponent)
   - Displays formatted transcript
   - Highlights current segment
   - Click-to-seek functionality

### Layout Structure

```
+------------------------+------------------+
|        Header         |                  |
+------------------------+                  |
| Timeline Visualization |   Transcript    |
+------------------------+     Editor      |
|                       |                  |
|      Video Player     |   Speaker Map    |
|                       |                  |
+------------------------+   Chapter List   |
|    Chapter Timeline   |                  |
+------------------------+------------------+
```

## CSS Structure

### New Tailwind Classes
- Timeline visualization classes
- Speaker color coding
- Chapter markers
- Hover states and tooltips
- Responsive layout adjustments

## Implementation Phases

### Phase 1: Core Structure
1. Update Inquiry schema
2. Create basic component structure
3. Implement layout with placeholder components

### Phase 2: Speaker Management
1. Implement SpeakerEditor component
2. Add speaker mapping functionality
3. Update transcript display with mapped names

### Phase 3: Timeline Visualization
1. Create TranscriptTimeline component
2. Implement hover tooltips
3. Add click-to-seek functionality

### Phase 4: Chapter Management
1. Implement ChapterManager component
2. Add chapter creation/editing interface
3. Integrate chapter markers with timeline

### Phase 5: Polish & Integration
1. Refine UI/UX
2. Add keyboard shortcuts
3. Implement responsive design
4. Add error handling and loading states

## Development Guidelines

### Component Communication
- Use Phoenix.PubSub for cross-component events
- Maintain single source of truth in LiveView
- Use hooks for JavaScript interop

### State Management
- Keep video state in VideoPlayer
- Maintain transcript state in LiveView
- Store speaker mappings in database
- Cache chapter data appropriately

### Performance Considerations
- Lazy load transcript segments
- Debounce timeline updates
- Optimize speaker mapping updates
- Use proper Phoenix.LiveView.JS operations

# Transcript Processing Pipeline

## Overview
This document outlines the pipeline for processing diarized transcripts using multiple LLMs via Instructor. The pipeline is designed to identify structural elements and chapter boundaries within parliamentary transcripts.

## Pipeline Steps

### 1. Transcript Marker Identification

#### Input
- Raw diarized transcript segments with speaker information
- Timestamp information

#### Output
List of transcript markers with:
- Marker type (question/remarks/procedure/testimony)
- Starting position in transcript
- Speaker information
- Confidence score

### 2. Chapter Boundary Detection

#### Input
- Processed transcript segments with markers
- Context window (e.g., 1000 tokens before and after current position)

#### Output
Chapter metadata including:
- Chapter type
- Start and end positions
- Primary speakers involved
- Confidence score
- Brief summary

## Implementation Notes

### LLM Configuration

1. **Marker Detection LLM**
   - Model: GPT-3.5-turbo
   - Temperature: 0.3
   - Max tokens: 150
   - Purpose: Quick identification of transcript markers

2. **Chapter Analysis LLM**
   - Model: GPT-4
   - Temperature: 0.2
   - Max tokens: 500
   - Purpose: Deep analysis of chapter boundaries and content

### Processing Strategy

1. **Sliding Window Approach**
   - Process transcript in overlapping windows
   - Window size: 2000 tokens
   - Overlap: 500 tokens

2. **Confidence Threshold**
   - Minimum confidence score: 0.85
   - Require human review for lower confidence scores

### Error Handling

1. **Conflict Resolution**
   - Handle overlapping chapter boundaries
   - Resolve conflicting marker classifications

2. **Quality Checks**
   - Verify speaker consistency
   - Validate chronological order
   - Check for missing segments

## Development Pipeline

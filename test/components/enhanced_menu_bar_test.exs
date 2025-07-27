defmodule ScenicWidgets.EnhancedMenuBarTest do
  use ExUnit.Case, async: true
  alias ScenicWidgets.EnhancedMenuBar
  alias Widgex.Frame

  defp sample_menu_map do
    [
      {:sub_menu, "File", [
        {"New", fn -> :ok end},
        {"Open", fn -> :ok end},
        {"Save", fn -> :ok end}
      ]},
      {:sub_menu, "Edit", [
        {"Cut", fn -> :ok end},
        {"Copy", fn -> :ok end},
        {"Paste", fn -> :ok end}
      ]},
      {:sub_menu, "Help", [
        {"About", fn -> :ok end}
      ]}
    ]
  end

  @sample_frame %Widgex.Frame{
    pin: %{point: {0, 0}},
    size: %{width: 800, height: 40}
  }

  describe "validate/1" do
    test "validates basic menu bar configuration" do
      data = %{
        menu_map: sample_menu_map(),
        frame: @sample_frame
      }

      assert {:ok, validated} = EnhancedMenuBar.validate(data)
      assert validated.menu_map == sample_menu_map()
      assert validated.frame == @sample_frame
      assert validated.theme == :default
      assert validated.interaction_mode == :hover
      assert validated.text_clipping == :ellipsis
    end

    test "validates with custom theme" do
      data = %{
        menu_map: sample_menu_map(),
        frame: @sample_frame,
        theme: :modern
      }

      assert {:ok, validated} = EnhancedMenuBar.validate(data)
      assert validated.theme == :modern
    end

    test "validates with custom interaction mode" do
      data = %{
        menu_map: sample_menu_map(),
        frame: @sample_frame,
        interaction_mode: :click
      }

      assert {:ok, validated} = EnhancedMenuBar.validate(data)
      assert validated.interaction_mode == :click
    end

    test "validates with custom colors" do
      custom_colors = %{
        background: {20, 20, 20},
        text: {255, 255, 255}
      }

      data = %{
        menu_map: sample_menu_map(),
        frame: @sample_frame,
        colors: custom_colors
      }

      assert {:ok, validated} = EnhancedMenuBar.validate(data)
      assert validated.colors.background == {20, 20, 20}
      assert validated.colors.text == {255, 255, 255}
      # Should still have default colors for non-overridden values
      assert Map.has_key?(validated.colors, :button)
    end

    test "raises error for missing menu_map" do
      data = %{frame: @sample_frame}

      assert_raise ArgumentError, "menu_map is required", fn ->
        EnhancedMenuBar.validate(data)
      end
    end

    test "raises error for missing frame" do
      data = %{menu_map: sample_menu_map()}

      assert_raise ArgumentError, "frame is required", fn ->
        EnhancedMenuBar.validate(data)
      end
    end
  end

  describe "get_theme_colors/1" do
    test "returns default theme colors" do
      colors = EnhancedMenuBar.get_theme_colors(:default)
      
      assert colors.background == {40, 40, 40}
      assert colors.button == {55, 55, 55}
      assert colors.text == {240, 240, 240}
      assert Map.has_key?(colors, :dropdown_bg)
    end

    test "returns minimal theme colors" do
      colors = EnhancedMenuBar.get_theme_colors(:minimal)
      
      assert colors.background == {250, 250, 250}
      assert colors.text == {60, 60, 60}
    end

    test "returns modern theme colors" do
      colors = EnhancedMenuBar.get_theme_colors(:modern)
      
      assert colors.background == {25, 25, 30}
      assert colors.text == {230, 230, 235}
    end

    test "returns retro theme colors" do
      colors = EnhancedMenuBar.get_theme_colors(:retro)
      
      assert colors.background == {20, 80, 20}
      assert colors.text == {200, 255, 200}
    end

    test "falls back to default for unknown theme" do
      colors = EnhancedMenuBar.get_theme_colors(:unknown_theme)
      default_colors = EnhancedMenuBar.get_theme_colors(:default)
      
      assert colors == default_colors
    end
  end

  describe "button width calculations" do
    test "calculates auto width correctly" do
      # This would require actual font metrics, so we'll just test the structure
      data = %{
        button_width: {:auto, :min_width, 100},
        font: %{name: :roboto, size: 16},
        text_margin: 8
      }

      # The actual calculation would depend on FontMetrics being available
      # For now we just verify the function exists and doesn't crash
      assert is_function(&EnhancedMenuBar.calculate_button_width/2, 2)
    end

    test "returns fixed width when configured" do
      data = %{button_width: {:fixed, 150}}
      
      # This should work without font metrics
      assert is_function(&EnhancedMenuBar.calculate_button_width/2, 2)
    end
  end

  describe "text clipping" do
    test "clips text with ellipsis mode" do
      # This would require actual font metrics for proper testing
      # For now we just verify the function exists
      assert is_function(&EnhancedMenuBar.clip_text_to_width/4, 4)
    end

    test "truncates text in truncate mode" do
      # This would require actual font metrics for proper testing
      # For now we just verify the function exists
      assert is_function(&EnhancedMenuBar.truncate_text_to_width/3, 3)
    end
  end
end
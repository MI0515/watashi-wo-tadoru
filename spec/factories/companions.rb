FactoryBot.define do
  factory :companion do
    association :personality_type
    appearance_type { "animal" }
    sd_image_path { "companions/nt-animal-sd.png" }
    full_image_path { "companions/nt-animal-full.png" }
    speaking_style { "casual" }
  end
end

import SwiftUI
import PhotosUI

private let commonBreeds = [
    "Labrador Retriever","Golden Retriever","French Bulldog","German Shepherd",
    "Poodle","Bulldog","Beagle","Rottweiler","Dachshund","Shih Tzu",
    "Siberian Husky","Doberman Pinscher","Yorkshire Terrier","Boxer",
    "Australian Shepherd","Cavalier King Charles Spaniel","Border Collie",
    "Pembroke Welsh Corgi","Miniature Schnauzer","Cocker Spaniel",
    "Great Dane","Maltese","Chihuahua","Vizsla","Weimaraner",
    "Bernese Mountain Dog","Havanese","Boston Terrier","Pomeranian",
    "Samoyed","Mixed / Other"
]

struct Step1BasicsView: View {
    @Bindable var vm: OnboardingViewModel
    @State private var showBreedPicker = false
    @State private var breedSearch = ""

    var filteredBreeds: [String] {
        breedSearch.isEmpty ? commonBreeds :
            commonBreeds.filter { $0.localizedCaseInsensitiveContains(breedSearch) }
    }

    var body: some View {
        OnboardingStep(
            title: "First, the basics",
            subtitle: "Tell us about your dog.",
            vm: vm,
            onSkip: { vm.advance() },
            continueLabel: "Continue",
            continueDisabled: vm.name.trimmingCharacters(in: .whitespaces).isEmpty
        ) {
            VStack(spacing: 20) {
                // Photo
                PhotosPicker(selection: $vm.selectedPhoto, matching: .images) {
                    Group {
                        if let data = vm.photoData, let ui = UIImage(data: data) {
                            Image(uiImage: ui)
                                .resizable().scaledToFill()
                        } else {
                            VStack(spacing: 8) {
                                Image(systemName: "camera.fill")
                                    .font(.jakarta(28))
                                    .foregroundColor(.snootOrange)
                                Text("Add photo")
                                    .font(.jakarta(14, weight: .medium))
                                    .foregroundColor(.snootOrange)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 120)
                            .background(Color.snootOrange.opacity(0.08))
                        }
                    }
                    .frame(width: 120, height: 120)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.snootOrange.opacity(0.3), lineWidth: 2))
                }
                .onChange(of: vm.selectedPhoto) { _, item in
                    Task {
                        if let data = try? await item?.loadTransferable(type: Data.self) {
                            vm.photoData = data
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)

                // Name
                VStack(alignment: .leading, spacing: 6) {
                    Label("Name", systemImage: "pawprint.fill")
                        .font(.jakarta(13, weight: .bold))
                        .foregroundColor(.snootText2)
                    HighContrastTextField(placeholder: "e.g. Biscuit", text: $vm.name)
                        .fieldStyle()
                }

                // Breed
                VStack(alignment: .leading, spacing: 6) {
                    Label("Breed", systemImage: "magnifyingglass")
                        .font(.jakarta(13, weight: .bold))
                        .foregroundColor(.snootText2)
                    Button { showBreedPicker = true } label: {
                        HStack {
                            Text(vm.breed)
                                .foregroundColor(.snootBrown)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.jakarta(13))
                                .foregroundColor(.snootText2)
                        }
                        .fieldStyle()
                    }
                    .buttonStyle(.plain)
                }

                // Date of birth
                VStack(alignment: .leading, spacing: 6) {
                    Label("Date of birth", systemImage: "calendar")
                        .font(.jakarta(13, weight: .bold))
                        .foregroundColor(.snootText2)
                    DatePicker("", selection: $vm.dateOfBirth, in: ...Date(), displayedComponents: .date)
                        .labelsHidden()
                        .padding(12)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: .black.opacity(0.04), radius: 4)
                }

                // Weight
                VStack(alignment: .leading, spacing: 6) {
                    Label("Weight (lbs)", systemImage: "scalemass")
                        .font(.jakarta(13, weight: .bold))
                        .foregroundColor(.snootText2)
                    HStack {
                        Button { if vm.weightLbs > 1 { vm.weightLbs -= 1 } } label: {
                            Image(systemName: "minus.circle.fill").font(.title2).foregroundColor(.snootOrange)
                        }
                        Spacer()
                        Text("\(Int(vm.weightLbs)) lbs")
                            .font(.jakarta(20, weight: .semibold))
                            .foregroundColor(.snootBrown)
                        Spacer()
                        Button { if vm.weightLbs < 250 { vm.weightLbs += 1 } } label: {
                            Image(systemName: "plus.circle.fill").font(.title2).foregroundColor(.snootOrange)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.04), radius: 4)
                }

                // Sex
                VStack(alignment: .leading, spacing: 6) {
                    Label("Gender", systemImage: "circle.lefthalf.filled")
                        .font(.jakarta(13, weight: .bold))
                        .foregroundColor(.snootText2)
                    HStack(spacing: 12) {
                        ForEach(["Male", "Female"], id: \.self) { option in
                            Button {
                                if !vm.readOnly {
                                    vm.gender = vm.gender == option ? "" : option
                                }
                            } label: {
                                Text(option)
                                    .font(.jakarta(14, weight: .medium))
                                    .foregroundColor(vm.gender == option ? .white : .snootBrown)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(vm.gender == option ? Color.snootOrange : Color.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .shadow(color: .black.opacity(0.04), radius: 4)
                            }
                            .buttonStyle(.plain)
                            .disabled(vm.readOnly)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showBreedPicker) {
            NavigationStack {
                List {
                    HighContrastTextField(placeholder: "Search breeds…", text: $breedSearch)
                        .padding(.vertical, 4)
                    ForEach(filteredBreeds, id: \.self) { breed in
                        Button {
                            vm.breed = breed
                            showBreedPicker = false
                        } label: {
                            HStack {
                                Text(breed)
                                Spacer()
                                if vm.breed == breed {
                                    Image(systemName: "checkmark").foregroundColor(.snootOrange)
                                }
                            }
                        }
                        .foregroundColor(.primary)
                    }
                }
                .navigationTitle("Choose Breed")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showBreedPicker = false }
                    }
                }
            }
        }
        }
    }


package com.spring.tourism.Controller;

import com.spring.tourism.Entity.UserEntity;
import com.spring.tourism.Entity.UserImageEntity;
import com.spring.tourism.Entity.UserTravelBookingEntity;
import com.spring.tourism.Entity.UserTravelSaveEntity;
import com.spring.tourism.Repository.*;
import com.spring.tourism.Support.FileSystemStorageService;
import com.spring.tourism.Support.SHA512;
import com.spring.tourism.Support.StorageFileNotFoundException;
import com.spring.tourism.Support.StorageProperties;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.core.io.ClassPathResource;
import org.springframework.core.io.Resource;
import org.springframework.data.repository.query.Param;
import org.springframework.http.HttpHeaders;
import org.springframework.http.ResponseEntity;
import org.springframework.lang.NonNull;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.web.servlet.mvc.method.annotation.MvcUriComponentsBuilder;
import org.springframework.web.servlet.mvc.support.RedirectAttributes;

import javax.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.io.PrintWriter;
import java.util.stream.Collectors;

@Controller
@RequestMapping(path = "/User")
public class UserController {
    private final StorageService storageService;

    private final UserTravelBookRepository userTravelBookRepository;

    private final UserTravelSaveRepository userTravelSaveRepository;

    private final UserRepository userRepository;

    private final UserImageRepository userImageRepository;

    private final UserRaiderRepository userRaiderRepository;

    private final UserSaveRaiderRepository userSaveRaiderRepository;

    private final UserStarRaiderRepository userStarRaiderRepository;

    @Autowired
    public UserController(UserRepository userRepository,
                          UserTravelSaveRepository userTravelSaveRepository,
                          UserTravelBookRepository userTravelBookRepository,
                          StorageService storageService,
                          UserImageRepository userImageRepository,
                          UserRaiderRepository userRaiderRepository,
                          UserSaveRaiderRepository userSaveRaiderRepository,
                          UserStarRaiderRepository userStarRaiderRepository) {

        this.userRepository = userRepository;
        this.userTravelSaveRepository = userTravelSaveRepository;
        this.userTravelBookRepository = userTravelBookRepository;
        this.storageService = storageService;
        this.userImageRepository = userImageRepository;
        this.userRaiderRepository = userRaiderRepository;
        this.userSaveRaiderRepository = userSaveRaiderRepository;
        this.userStarRaiderRepository = userStarRaiderRepository;
    }

    @PostMapping(path = "/updateUserPassword")
    public String updateUserPassword(@Param("userId") String userId,
                                     @Param("userPassword") String userPassword) {
        if (userId == null || userId.trim().length() == 0) {
            throw new IllegalArgumentException("update user password userId valid length is 0");
        }

        if (userPassword == null || userPassword.trim().length() == 0) {
            throw new IllegalArgumentException("update user password userPassword valid length is 0");
        }

        try {
            String encryptionPassword = new SHA512().encryptThisString(userPassword);
            userRepository.updateUserPassword(encryptionPassword, userId);
            System.out.println();
            return "login";
        } catch (Exception e) {
            return "login";
        }
    }

    @PostMapping(path = "/updateUserName")
    public String updateUserName(@Param("userName") String userName,
                                 @Param("userId") String userId) {
        if (userId == null || userId.trim().length() == 0) {
            throw new IllegalArgumentException("update user name userId valid length is 0");
        }

        if (userName == null || userName.trim().length() == 0) {
            throw new IllegalArgumentException("update user name userName valid length is 0");
        }

        try {
            userRepository.updateUserName(userName, userId);
            return "login";
        } catch (Exception e) {
            return "login";
        }
    }

    @GetMapping(path = "/getUserEntityByUserId")
    public void getUserEntityByUserId(@Param("userId") String userId,
                                      HttpServletResponse response) throws IOException {
        if (userId == null || userId.trim().length() == 0) {
            throw new IllegalArgumentException("get userEntity by userId userId valid length is 0");
        }

        try (PrintWriter printWriter = response.getWriter()) {
            UserEntity userEntity = userRepository.getUserEntityByUserId(userId);
            if (userEntity != null) {
                printWriter.write("1");
            } else {
                printWriter.write("0");
            }
        } catch (Exception e) {
            response.getWriter().write("0");
        }
    }

    @PostMapping(path = "/getUserByIdAndPassword")
    public void getUserByIdAndPassword(String userId,
                                         String userPassword,
                                         HttpServletResponse response) throws IOException {
        try (PrintWriter printWriter = response.getWriter()){
            if (userId == null || userId.trim().length() == 0) {
                System.out.println("get userId valid length is 0");
                printWriter.write("0");
            }
            if (userPassword == null || userPassword.trim().length() == 0) {
                System.out.println("get userPassword valid length is 0");
                printWriter.write("0");
            }

            String password = new SHA512().encryptThisString(userPassword);
            UserEntity userEntity = userRepository.
                    getUserEntityByUserIdAndUserPassword(userId, password);
            if (userEntity != null) {
                printWriter.write("1");
            } else {
                printWriter.write("0");
            }
        } catch (Exception e) {
            response.getWriter().write("0");
        }
    }

    @GetMapping(path = "/addUserSaveTravel")
    public void addUserSaveTravel(HttpServletResponse response,
                                  String travelId,
                                  @CookieValue(name = "userId") String userId) throws IOException {
        try(PrintWriter printWriter = response.getWriter()) {
            if (userId == null || userId.trim().length() == 0) {
                printWriter.write("0");
            }
            if (travelId == null || travelId.trim().length() == 0) {
                printWriter.write("0");
            }

            UserTravelSaveEntity userTravelSaveEntity = new UserTravelSaveEntity();
            userTravelSaveEntity.setTravelId(travelId);
            userTravelSaveEntity.setUserId(userId);

            userTravelSaveRepository.save(userTravelSaveEntity);

            printWriter.write("1");
        } catch (Exception e) {
            response.getWriter().write("-1");
        }
    }

    @GetMapping(path = "/addBookTravel")
    private void addBookTravel(HttpServletResponse response,
                               String travelId,
                               String travelDate,
                               String travelPrice,
                               @CookieValue(value = "userId") String userId) throws IOException {
        try (PrintWriter printWriter = response.getWriter()) {
            if (userId == null || userId.trim().length() == 0) {
                printWriter.write("0");
            }
            if (travelId == null || travelId.trim().length() == 0) {
                printWriter.write("0");
            }
            if (travelDate == null || travelDate.trim().length() == 0) {
                printWriter.write("0");
            }
            if (travelPrice == null || travelPrice.trim().length() == 0) {
                printWriter.write("0");
            }

            UserTravelBookingEntity userTravelBookingEntity =
                    new UserTravelBookingEntity();
            userTravelBookingEntity.setBookDate(travelDate);
            userTravelBookingEntity.setTravelId(travelId);
            assert travelPrice != null;
            userTravelBookingEntity.setTravelPrice(Double.parseDouble(travelPrice));
            userTravelBookingEntity.setUserId(userId);

            userTravelBookRepository.save(userTravelBookingEntity);

            printWriter.write("1");
        } catch (Exception e) {
            response.getWriter().write("-1");
        }
    }

    @GetMapping(path = "/updateUserName")
    public void updateUserName(@NonNull String userName,
                               HttpServletResponse response,
                               @CookieValue(value = "userId") String userId) throws IOException {
        try (PrintWriter printWriter = response.getWriter()){
            if (userName.trim().length() == 0) {
                printWriter.write("0");
            }

            if (userId == null || userId.trim().length() == 0) {
                printWriter.write("0");
            }

            userRepository.updateUserName(userName, userId);

            printWriter.write("1");
        } catch (Exception e) {
            response.getWriter().write("0");
        }
    }

    @GetMapping(path = "/modifyHeadImage")
    public String modifyUserHeadImage(Model model) {
        try {
            model.addAttribute("files", storageService.loadAll().map(
                    path -> MvcUriComponentsBuilder.fromMethodName(UserController.class,
                            "serveFile",
                            path.getFileName().toString())
                            .build().toUri().toString())
                            .collect(Collectors.toList()));

            return "modifyHeadImage";
        } catch (Exception e) {
            return "error";
        }
    }

    @GetMapping("/files/{filename:.+}")
    @ResponseBody
    public ResponseEntity<Resource> serveFile(@PathVariable String filename) {
        Resource file = storageService.loadAsResource(filename);
        System.out.println(ResponseEntity.ok().header(HttpHeaders.CONTENT_DISPOSITION,
                "attachment; filename=\"" + file.getFilename() + "\"").body(file).toString());
        return ResponseEntity.ok().header(HttpHeaders.CONTENT_DISPOSITION,
                "attachment; filename=\"" + file.getFilename() + "\"").body(file);
    }

    @PostMapping(path = "/modifyHeadImage")
    public String modifyHeadImage(@RequestParam("file") MultipartFile file,
                                  RedirectAttributes redirectAttributes,
                                  @CookieValue(value = "userId") String userId) {
        try {
            Resource resource = new ClassPathResource("application.properties");
            StorageProperties storageProperties = new StorageProperties();
            storageProperties.setLocation(resource.getFile().getParent().
                    replaceAll("\\\\", "/") + "/static"
                    + "/userImage/" +  userId);

            FileSystemStorageService fileSystemStorageService =
                    new FileSystemStorageService(storageProperties);
            fileSystemStorageService.init();

            UserImageEntity userImageEntity = new UserImageEntity();
            userImageEntity.setUserId(userId);
            userImageEntity.setImageAddress("/userImage/" + userId + "/" + file.getOriginalFilename());
            userImageRepository.addUserImage(userImageEntity.getUserId(),
                    userImageEntity.getImageAddress());

            fileSystemStorageService.store(file);
            redirectAttributes.addFlashAttribute("message",
                    "You successfully uploaded " + file.getOriginalFilename() + "!");

            return "redirect:/myInfo";
        } catch (Exception e) {
            return "error";
        }
    }

    @ExceptionHandler(StorageFileNotFoundException.class)
    public ResponseEntity<?> handleStorageFileNotFound(StorageFileNotFoundException exc) {
        return ResponseEntity.notFound().build();
    }

    @GetMapping(path = "/removeRaiderByUserId")
    public void removeRaiderByUserId(HttpServletResponse response,
                                     @NonNull String raiderId,
                                     @CookieValue(value = "userId") String userId) throws IOException {
        try(PrintWriter printWriter = response.getWriter()) {
            if (raiderId.trim().length() == 0) {
                printWriter.write("0");
            }

            if (userId == null || userId.trim().length() == 0) {
                printWriter.write("0");
            }

            System.out.println("userId: " + userId + "\traider_id: " + raiderId);

            userRaiderRepository.deleteUserRaiderEntityUseQuery(raiderId, userId);
            printWriter.write("1");
        } catch (Exception e) {
            response.getWriter().write("0");
        }
    }

    @GetMapping(path = "/removeSaveRaider")
    public void removeSaveRaiderByUserId(HttpServletResponse response,
                                         @NonNull String raiderId,
                                         @CookieValue(value = "userId") String userId) throws IOException {
        try (PrintWriter printWriter = response.getWriter()){
            if (raiderId.trim().length() == 0){
                printWriter.write("0");
            }
            if (userId == null || userId.trim().length() == 0) {
                printWriter.write("0");
            }

            userSaveRaiderRepository.
                    deleteUserSaveRaiderEntityByRaiderIdAndAndUserIdUseQuery(raiderId, userId);
            printWriter.write("1");
        } catch (Exception e) {
            response.getWriter().write("0");
        }
    }

    @GetMapping(path = "/removeStarRaider")
    public void removeStarRaider(HttpServletResponse response,
                                 @NonNull String raiderId,
                                 @CookieValue(value = "userId") String userId) throws IOException {
        try (PrintWriter printWriter = response.getWriter()){
            if (raiderId.trim().length() == 0) {
                printWriter.write("0");
            }

            if (userId == null || userId.trim().length() == 0) {
                printWriter.write("0");
            }

            userStarRaiderRepository.
                    deleteUserStarRaiderEntityByRaiderIdAndUserIdUseQuery(raiderId, userId);

            printWriter.write("1");
        } catch (Exception e) {
            response.getWriter().write("0");
        }
    }
}
